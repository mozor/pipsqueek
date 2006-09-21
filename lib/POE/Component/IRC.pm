# $Id: IRC.pm,v 1.11 1999/12/12 11:48:07 dennis Exp $
#
# POE::Component::IRC, by Dennis Taylor <dennis@funkplanet.com>
#
# This module may be used, modified, and distributed under the same
# terms as Perl itself. Please see the license that came with your Perl
# distribution for details.
#

package POE::Component::IRC;

use strict;
use POE qw( Wheel::SocketFactory Wheel::ReadWrite Driver::SysRW
	    Filter::Line Filter::Stream );
use POE::Filter::IRC;
use POE::Filter::CTCP;
use Carp;
use Socket;
use Sys::Hostname;
use File::Basename ();
use Symbol;
use vars qw($VERSION);

# The name of the reference count P::C::I keeps in client sessions.
use constant PCI_REFCOUNT_TAG => "P::C::I registered";

use constant BLOCKSIZE => 1024;           # Send DCC data in 1k chunks
use constant INCOMING_BLOCKSIZE => 10240; # 10k per DCC socket read
use constant DCC_TIMEOUT => 300;          # Five minutes for listening DCCs

# Message priorities.
use constant PRI_LOGIN  => 10; # PASS/NICK/USER messages must go first.
use constant PRI_HIGH   => 20; # KICK/MODE etc. is more important than chatter.
use constant PRI_NORMAL => 30; # Random chatter.

use constant MSG_PRI  => 0; # Queued message priority.
use constant MSG_TEXT => 1; # Queued message text.

# RCC: Since most of the commands are data driven, I have moved their
# event/handler maps here and added priorities for each data driven
# command.  The priorities determine message importance when messages
# are queued up.  Lower ones get sent first.

use constant CMD_PRI => 0; # Command priority.
use constant CMD_SUB => 1; # Command handler.

my %irc_commands =
  ( 'rehash'    => [ PRI_HIGH,   \&noargs,        ],
    'restart'   => [ PRI_HIGH,   \&noargs,        ],
    'quit'      => [ PRI_NORMAL, \&oneoptarg,     ],
    'version'   => [ PRI_HIGH,   \&oneoptarg,     ],
    'time'      => [ PRI_HIGH,   \&oneoptarg,     ],
    'trace'     => [ PRI_HIGH,   \&oneoptarg,     ],
    'admin'     => [ PRI_HIGH,   \&oneoptarg,     ],
    'info'      => [ PRI_HIGH,   \&oneoptarg,     ],
    'away'      => [ PRI_HIGH,   \&oneoptarg,     ],
    'users'     => [ PRI_HIGH,   \&oneoptarg,     ],
    'wallops'   => [ PRI_HIGH,   \&oneoptarg,     ],
    'motd'      => [ PRI_HIGH,   \&oneoptarg,     ],
    'who'       => [ PRI_HIGH,   \&oneoptarg,     ],
    'nick'      => [ PRI_HIGH,   \&onlyonearg,    ],
    'oper'      => [ PRI_HIGH,   \&onlytwoargs,   ],
    'invite'    => [ PRI_HIGH,   \&onlytwoargs,   ],
    'squit'     => [ PRI_HIGH,   \&onlytwoargs,   ],
    'kill'      => [ PRI_HIGH,   \&onlytwoargs,   ],
    'privmsg'   => [ PRI_NORMAL, \&privandnotice, ],
    'privmsglo' => [ PRI_NORMAL+1, \&privandnotice, ],
    'privmsghi' => [ PRI_NORMAL-1, \&privandnotice, ],
    'notice'    => [ PRI_NORMAL, \&privandnotice, ],
    'noticelo'  => [ PRI_NORMAL+1, \&privandnotice, ],   
    'noticehi'  => [ PRI_NORMAL-1, \&privandnotice, ],   
    'join'      => [ PRI_HIGH,   \&oneortwo,      ],
    'summon'    => [ PRI_HIGH,   \&oneortwo,      ],
    'sconnect'  => [ PRI_HIGH,   \&oneandtwoopt,  ],
    'whowas'    => [ PRI_HIGH,   \&oneandtwoopt,  ],
    'stats'     => [ PRI_HIGH,   \&spacesep,      ],
    'links'     => [ PRI_HIGH,   \&spacesep,      ],
    'mode'      => [ PRI_HIGH,   \&mode,          ],
    'part'      => [ PRI_HIGH,   \&commasep_c,    ],
    'names'     => [ PRI_HIGH,   \&commasep_c,    ],
    'list'      => [ PRI_HIGH,   \&commasep_c,    ],
    'whois'     => [ PRI_HIGH,   \&commasep,      ],
    'ctcp'      => [ PRI_HIGH,   \&ctcp,          ],
    'ctcpreply' => [ PRI_HIGH,   \&ctcp,          ],
  );

my %c_lookup = (); # channel lookup hash

$VERSION = '2.9';


# What happens when an attempted DCC connection fails.
sub _dcc_failed {
  my ($kernel, $heap, $operation, $errnum, $errstr, $id) =
    @_[KERNEL, HEAP, ARG0 .. ARG3];

  unless (exists $heap->{dcc}->{$id}) {
    if (exists $heap->{wheelmap}->{$id}) {
      $id = $heap->{wheelmap}->{$id};
    } else {
      die "Unknown wheel ID: $id";
    }
  }

  # Did the peer of a DCC GET connection close the socket after the file
  # transfer finished? If so, it's not really an error.
  if ($errnum == 0 and $heap->{dcc}->{$id}->{type} eq "GET" and
      $heap->{dcc}->{$id}->{done} >= $heap->{dcc}->{$id}->{size}) {
    _send_event( $kernel, $heap, 'irc_dcc_done', $id,
		 @{$heap->{dcc}->{$id}}{ qw(nick type port file size done) } );
    close $heap->{dcc}->{$id}->{fh};
    delete $heap->{wheelmap}->{$heap->{dcc}->{$id}->{wheel}->ID};
    delete $heap->{dcc}->{$id}->{wheel};
    delete $heap->{dcc}->{$id};

  } else {
    # In this case, something went wrong.
    if ($errnum == 0 and $heap->{dcc}->{$id}->{type} eq "GET") {
      $errstr = "Aborted by sender";
    }
    else {
      $errstr = "$operation error $errnum: $errstr";
    }
    _send_event( $kernel, $heap, 'irc_dcc_error', $id, $errstr,
		 @{$heap->{dcc}->{$id}}{qw(nick type port file size done)} );
    # gotta close the file
    close $heap->{dcc}->{$id}->{fh} if exists $heap->{dcc}->{$id}->{fh};
    if (exists $heap->{dcc}->{$id}->{wheel}) {
      delete $heap->{wheelmap}->{$heap->{dcc}->{$id}->{wheel}->ID};
      delete $heap->{dcc}->{$id}->{wheel};
    }
    delete $heap->{dcc}->{$id};
  }
}


# Accept incoming data on a DCC socket.
sub _dcc_read {
  my ($kernel, $heap, $data, $id) = @_[KERNEL, HEAP, ARG0, ARG1];

  $id = $heap->{wheelmap}->{$id};

  if ($heap->{dcc}->{$id}->{type} eq "GET") {

    # Acknowledge the received data.
    print {$heap->{dcc}->{$id}->{fh}} $data;
    $heap->{dcc}->{$id}->{done} += length $data;
    $heap->{dcc}->{$id}->{wheel}->put( pack "N", $heap->{dcc}->{$id}->{done} );

    # Send an event to let people know about the newly arrived data.
    _send_event( $kernel, $heap, 'irc_dcc_get', $id,
		 @{$heap->{dcc}->{$id}}{ qw(nick port file size done) } );


  } elsif ($heap->{dcc}->{$id}->{type} eq "SEND") {

    # Record the client's download progress.
    $heap->{dcc}->{$id}->{done} = unpack "N", substr( $data, -4 );
    _send_event( $kernel, $heap, 'irc_dcc_send', $id,
		 @{$heap->{dcc}->{$id}}{ qw(nick port file size done) } );

    # Are we done yet?
    if ($heap->{dcc}->{$id}->{done} >= $heap->{dcc}->{$id}->{size}) {
      _send_event( $kernel, $heap, 'irc_dcc_done', $id,
		   @{$heap->{dcc}->{$id}}{ qw(nick type port file size done) }
		 );
      delete $heap->{wheelmap}->{$heap->{dcc}->{$id}->{wheel}->ID};
      delete $heap->{dcc}->{$id}->{wheel};
      delete $heap->{dcc}->{$id};
      return;
    }

    # Send the next 'blocksize'-sized packet.
    read $heap->{dcc}->{$id}->{fh}, $data, $heap->{dcc}->{$id}->{blocksize};
    $heap->{dcc}->{$id}->{wheel}->put( $data );

  } else {
    _send_event( $kernel, $heap, 'irc_dcc_' . lc $heap->{dcc}->{$id}->{type},
		 $id, @{$heap->{dcc}->{$id}}{'nick', 'port'}, $data );
  }
}


# What happens when a DCC connection sits waiting for the other end to
# pick up the phone for too long.
sub _dcc_timeout {
  my ($kernel, $heap, $id) = @_[KERNEL, HEAP, ARG0];

  if (exists $heap->{dcc}->{$id} and not $heap->{dcc}->{$id}->{open}) {
    $kernel->yield( '_dcc_failed', 'connection', 0,
		    'DCC connection timed out', $id );
  }
}


# This event occurs when a DCC connection is established.
sub _dcc_up {
  my ($kernel, $heap, $sock, $addr, $port, $id) =
    @_[KERNEL, HEAP, ARG0 .. ARG3];
  my $buf = '';

  # Monitor the new socket for incoming data and delete the listening socket.
  delete $heap->{dcc}->{$id}->{factory};
  $heap->{dcc}->{$id}->{addr} = $addr;
  $heap->{dcc}->{$id}->{port} = $port;
  $heap->{dcc}->{$id}->{open} = 1;
  $heap->{dcc}->{$id}->{wheel} = POE::Wheel::ReadWrite->new(
      Handle => $sock,
      Driver => ($heap->{dcc}->{$id}->{type} eq "GET" ?
		   POE::Driver::SysRW->new( BlockSize => INCOMING_BLOCKSIZE ) :
		   POE::Driver::SysRW->new() ),
      Filter => ($heap->{dcc}->{$id}->{type} eq "CHAT" ?
                     POE::Filter::Line->new( Literal => "\012" ) :
		     POE::Filter::Stream->new() ),
      InputEvent => '_dcc_read',
      ErrorEvent => '_dcc_failed',
  );
  $heap->{wheelmap}->{$heap->{dcc}->{$id}->{wheel}->ID} = $id;

  if ($heap->{dcc}->{$id}->{'type'} eq 'GET') {
    my $handle = gensym();
    unless (open $handle, ">" . $heap->{dcc}->{$id}->{file}) {
      $kernel->yield( '_dcc_failed', 'open file', $! + 0, "$!", $id );
      return;
    }
    binmode $handle;

    # Store the filehandle with the rest of this connection's state.
    $heap->{dcc}->{$id}->{'fh'} = $handle;

  } elsif ($heap->{dcc}->{$id}->{type} eq 'SEND') {
    # Open up the file we're going to send.
    my $handle = gensym();
    unless (open $handle, "<" . $heap->{dcc}->{$id}->{'file'}) {
      $kernel->yield( '_dcc_failed', 'open file', $! + 0, "$!", $id );
      return;
    }
    binmode $handle;

    # Send the first packet to get the ball rolling.
    read $handle, $buf, $heap->{dcc}->{$id}->{'blocksize'};
    $heap->{dcc}->{$id}->{wheel}->put( $buf );

    # Store the filehandle with the rest of this connection's state.
    $heap->{dcc}->{$id}->{'fh'} = $handle;
  }

  # Tell any listening sessions that the connection is up.
  _send_event( $kernel, $heap, 'irc_dcc_start',
	       $id, @{$heap->{dcc}->{$id}}{'nick', 'type', 'port'},
	       ($heap->{dcc}->{$id}->{'type'} =~ /^(SEND|GET)$/ ?
		(@{$heap->{dcc}->{$id}}{'file', 'size'}) : ()) );
}


# Parse a message from the IRC server and generate the appropriate
# event(s) for listening sessions.
sub _parseline {
  my ($kernel, $session, $heap, $line) = @_[KERNEL, SESSION, HEAP, ARG0];
  my (@events, @cooked);

  # Feed the proper Filter object the raw IRC text and get the
  # "cooked" events back for sending, then deliver each event. We
  # handle CTCPs separately from normal IRC messages here, to avoid
  # silly module dependencies later.

  @cooked = ($line =~ tr/\001// ? @{$heap->{ctcp_filter}->get( [$line] )}
	     : @{$heap->{irc_filter}->get( [$line] )} );

  foreach my $ev (@cooked) {
    $ev->{name} = 'irc_' . $ev->{name};
    _send_event( $kernel, $heap, $ev->{name}, @{$ev->{args}} );
  }
}


# Sends an event to all interested sessions. This is a separate sub
# because I do it so much, but it's not an actual POE event because it
# doesn't need to be one and I don't need the overhead.
sub _send_event  {
  my ($kernel, $heap, $event, @args) = @_;
  my %sessions;

  # ah, we got an irc_join event here - let's get the channel ID
  if( $event eq 'irc_join' )
  {
    my $c = $args[1];
    $c =~ s/^([#!&+])//; # strip channel prefix
    my ($key) = grep { $c =~ /$_$/i } keys %c_lookup;
    $c_lookup{lc($key)} = $args[1];
  }

  foreach (values %{$heap->{events}->{'irc_all'}},
	   values %{$heap->{events}->{$event}}) {
    $sessions{$_} = $_;
  }
  foreach (values %sessions) {
    $kernel->post( $_, $event, @args );
  }
}


# Internal function called when a socket is closed.
sub _sock_down {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  # Destroy the RW wheel for the socket.
  delete $heap->{'socket'};
  $heap->{connected} = 0;

  # Stop any delayed sends.
  $heap->{send_queue} = [ ];
  $heap->{send_time}  = 0;
  $kernel->delay( sl_delayed => undef );

  # post a 'irc_disconnected' to each session that cares
  foreach (keys %{$heap->{sessions}}) {
    $kernel->post( $heap->{sessions}->{$_}->{'ref'},
		   'irc_disconnected', $heap->{server} );
  }
}


# Internal function called when a socket fails to be properly opened.
sub _sock_failed {
  my ($kernel, $heap, $op, $errno, $errstr) = @_[KERNEL, HEAP, ARG0..ARG2];

  _send_event( $kernel, $heap, 'irc_socketerr', "$op error $errno: $errstr" );
}


# Internal function called when a connection is established.
sub _sock_up {
  my ($kernel, $heap, $session, $socket) = @_[KERNEL, HEAP, SESSION, ARG0];

  # We no longer need the SocketFactory wheel. Scrap it.
  delete $heap->{'socketfactory'};

  # Remember what IP address we're connected through, for multihomed boxes.
  $heap->{'localaddr'} = (unpack_sockaddr_in( getsockname $socket ))[1];

  # Create a new ReadWrite wheel for the connected socket.
  $heap->{'socket'} = new POE::Wheel::ReadWrite
    ( Handle     => $socket,
      Driver     => POE::Driver::SysRW->new(),
      Filter     => POE::Filter::Line->new( InputRegexp => '\015?\012',
					    OutputLiteral => "\015\012" ),
      InputEvent => '_parseline',
      ErrorEvent => '_sock_down',
    );

  if ($heap->{'socket'}) {
    $heap->{connected} = 1;
  } else {
    _send_event( $kernel, $heap, 'irc_socketerr',
		 "Couldn't create ReadWrite wheel for IRC socket" );
  }

  # Post a 'irc_connected' event to each session that cares
  foreach (keys %{$heap->{sessions}}) {
    $kernel->post( $heap->{sessions}->{$_}->{'ref'},
		   'irc_connected', $heap->{server} );
  }

  # Now that we're connected, attempt to log into the server.
  if ($heap->{password}) {
    $kernel->call( $session, 'sl_login', "PASS " . $heap->{password} );
  }
  $kernel->call( $session, 'sl_login', "NICK " . $heap->{nick} );
  $kernel->call( $session, 'sl_login', "USER " .
		 join( ' ', $heap->{username},
		       "foo.bar.com",
		       $heap->{server},
		       ':' . $heap->{ircname} ));

  # If we have queued data waiting, its flush loop has stopped
  # while we were disconnected.  Start that up again.
  $kernel->delay(sl_delayed => 0);
}


# Set up the component's IRC session.
sub _start {
  my ($kernel, $session, $heap, $alias) = @_[KERNEL, SESSION, HEAP, ARG0];
  my @options = @_[ARG1 .. $#_];

  # Send queue is used to hold pending lines so we don't flood off.
  # The count is used to track the number of lines sent at any time.
  $heap->{send_queue} = [ ];
  $heap->{send_time}  = 0;

  $session->option( @options ) if @options;
  $kernel->alias_set($alias);
  $kernel->yield( 'register', 'ping' );
  $heap->{irc_filter} = POE::Filter::IRC->new();
  $heap->{ctcp_filter} = POE::Filter::CTCP->new();
}


# Destroy ourselves when asked politely.
sub _stop {
  my ($kernel, $heap, $quitmsg) = @_[KERNEL, HEAP, ARG0];

  if ($heap->{connected}) {
    $kernel->call( $_[SESSION], 'quit', $quitmsg );
    $kernel->call( $_[SESSION], 'shutdown', $quitmsg );
  }
}


# The handler for commands which have N arguments, separated by commas.
sub commasep {
  my ($kernel, $state) = @_[KERNEL, STATE];
  my $args = join ',', @_[ARG0 .. $#_];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  $state = uc $state;
  $state .= " $args" if defined $args;
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# Handler for commands which have N comma-separated args (that are channels)
sub commasep_c {
  my ($kernel, $state, @args) = @_[KERNEL, STATE, ARG0 .. $#_];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  $state = uc $state;

  foreach my $x ( 0 .. $#args )
  {
    # look up the channel ID
    my ($chan) = $args[$x] =~ m/^[#&+!](.*)$/;
    $args[$x] = $c_lookup{lc($chan)} || $args[$x];
  }

  local $" = ",";
  $state .= " @args" if @args;
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# Attempt to connect this component to an IRC server.
sub connect {
  my ($kernel, $heap, $session, $args) = @_[KERNEL, HEAP, SESSION, ARG0];

  if ($args) {
    my %arg;
    if (ref $args eq 'ARRAY') {
      %arg = @$args;
    } elsif (ref $args eq 'HASH') {
      %arg = %$args;
    } else {
      die "First argument to connect() should be a hash or array reference";
    }

    if (exists $arg{'Flood'} and $arg{'Flood'}) {
      $heap->{'dont_flood'} = 0;
    } else {
      $heap->{'dont_flood'} = 1;
    }

    $heap->{'password'} = $arg{'Password'} if exists $arg{'Password'};
    $heap->{'localaddr'} = $arg{'LocalAddr'} if exists $arg{'LocalAddr'};
    $heap->{'localport'} = $arg{'LocalPort'} if exists $arg{'LocalPort'};
    $heap->{'nick'} = $arg{'Nick'} if exists $arg{'Nick'};
    $heap->{'port'} = $arg{'Port'} if exists $arg{'Port'};
    $heap->{'server'} = $arg{'Server'} if exists $arg{'Server'};
    $heap->{'ircname'} = $arg{'Ircname'} if exists $arg{'Ircname'};
    $heap->{'username'} = $arg{'Username'} if exists $arg{'Username'};
    if (exists $arg{'Debug'}) {
      $heap->{'debug'} = $arg{'Debug'};
      $heap->{irc_filter}->debug( $arg{'Debug'} );
      $heap->{ctcp_filter}->debug( $arg{'Debug'} );
    }
  }

  # Make sure that we have reasonable defaults for all the attributes.
  # The "IRC*" variables are ircII environment variables.
  $heap->{'nick'} = $ENV{IRCNICK} || eval { scalar getpwuid($>) } ||
    $ENV{USER} || $ENV{LOGNAME} || "WankerBot"
      unless ($heap->{'nick'});
  $heap->{'username'} = eval { scalar getpwuid($>) } || $ENV{USER} ||
    $ENV{LOGNAME} || "foolio"
      unless ($heap->{'username'});
  $heap->{'ircname'} = $ENV{IRCNAME} || eval { (getpwuid $>)[6] } ||
    "Just Another Perl Hacker"
      unless ($heap->{'ircname'});
  unless ($heap->{'server'}) {
    die "No IRC server specified" unless $ENV{IRCSERVER};
    $heap->{'server'} = $ENV{IRCSERVER};
  }
  $heap->{'port'} = 6667 unless $heap->{'port'};
  if ($heap->{localaddr} and $heap->{localport}) {
    $heap->{localaddr} .= ":" . $heap->{localport};
  }

  # Disconnect if we're already logged into a server.
  if ($heap->{'sock'}) {
    $kernel->call( $session, 'quit' );
  }

  $heap->{'socketfactory'} =
    POE::Wheel::SocketFactory->new( SocketDomain   => AF_INET,
				    SocketType     => SOCK_STREAM,
				    SocketProtocol => 'tcp',
				    RemoteAddress  => $heap->{'server'},
				    RemotePort     => $heap->{'port'},
				    SuccessEvent   => '_sock_up',
				    FailureEvent   => '_sock_failed',
				    ($heap->{localaddr} ?
				       (BindAddress => $heap->{localaddr}) : ()),
				  );
}


# Send a CTCP query or reply, with the same syntax as a PRIVMSG event.
sub ctcp {
  my ($kernel, $state, $heap, $to) = @_[KERNEL, STATE, HEAP, ARG0];
  my $message = join ' ', @_[ARG1 .. $#_];

  unless (defined $to and defined $message) {
    die "The POE::Component::IRC event \"$state\" requires two arguments";
  }

  # CTCP-quote the message text.
  ($message) = @{$heap->{ctcp_filter}->put([ $message ])};

  # Should we send this as a CTCP request or reply?
  $state = $state eq 'ctcpreply' ? 'notice' : 'privmsg';

  $kernel->yield( $state, $to, $message );
}


# Attempt to initiate a DCC SEND or CHAT connection with another person.
sub dcc {
  my ($kernel, $heap, $nick, $type, $file, $blocksize) =
    @_[KERNEL, HEAP, ARG0 .. ARG3];
  my ($factory, $port, $myaddr, $size);

  unless ($type) {
    die "The POE::Component::IRC event \"dcc\" requires at least two arguments";
  }

  $type = uc $type;
  if ($type eq 'CHAT') {
    $file = 'chat';		# As per the semi-specification

  } elsif ($type eq 'SEND') {
    unless ($file) {
      die "The POE::Component::IRC event \"dcc\" requires three arguments for a SEND";
    }
    $size = (stat $file)[7];
    unless (defined $size) {
      _send_event( $kernel, $heap, 'irc_dcc_error', 0,
		   "Couldn't get ${file}'s size: $!", $nick, $type, 0, $file );
    }
  }

  if ($heap->{localaddr} and $heap->{localaddr} =~ tr/a-zA-Z.//) {
    $heap->{localaddr} = inet_aton( $heap->{localaddr} );
  }

  $factory = POE::Wheel::SocketFactory->new(
      BindAddress  => $heap->{localaddr} || INADDR_ANY,
      BindPort     => 0,
      SuccessEvent => '_dcc_up',
      FailureEvent => '_dcc_failed',
      Reuse        => 'yes',
  );
  ($port, $myaddr) = unpack_sockaddr_in( $factory->getsockname() );
  $myaddr = $heap->{localaddr} || inet_aton(hostname() || 'localhost');
  die "Can't determine our IP address! ($!)" unless $myaddr;
  $myaddr = unpack "N", $myaddr;

  # Tell the other end that we're waiting for them to connect.
  my $basename = File::Basename::basename( $file );
  $basename =~ s/\s/_/g;

  $kernel->yield( 'ctcp', $nick, "DCC $type $basename $myaddr $port"
		  . ($size ? " $size" : "") );

  # Store the state for this connection.
  $heap->{dcc}->{$factory->ID} = { open => undef,
				   nick => $nick,
				   type => $type,
				   file => $file,
				   size => $size,
				   port => $port,
				   addr => $myaddr,
				   done => 0,
				   blocksize => ($blocksize || BLOCKSIZE),
				   factory => $factory,
				 };
  $kernel->alarm( '_dcc_timeout', time() + DCC_TIMEOUT, $factory->ID );
}


# Accepts a proposed DCC connection to another client. See '_dcc_up' for
# the rest of the logic for this.
sub dcc_accept {
  my ($kernel, $heap, $cookie, $myfile) = @_[KERNEL, HEAP, ARG0, ARG1];

  if ($cookie->{type} eq 'SEND') {
    $cookie->{type} = 'GET';
    $cookie->{file} = $myfile if defined $myfile;   # filename override
  }

  my $factory = POE::Wheel::SocketFactory->new(
      RemoteAddress => $cookie->{addr},
      RemotePort    => $cookie->{port},
      SuccessEvent  => '_dcc_up',
      FailureEvent  => '_dcc_failed',
  );
  $heap->{dcc}->{$factory->ID} = $cookie;
  $heap->{dcc}->{$factory->ID}->{factory} = $factory;
}


# Send data over a DCC CHAT connection.
sub dcc_chat {
  my ($kernel, $heap, $id, @data) = @_[KERNEL, HEAP, ARG0, ARG1 .. $#_];

  die "Unknown wheel ID: $id" unless exists $heap->{dcc}->{$id};
  die "No DCC wheel for $id!" unless exists $heap->{dcc}->{$id}->{wheel};
  die "$id isn't a DCC CHAT connection!"
    unless $heap->{dcc}->{$id}->{type} eq "CHAT";

  $heap->{dcc}->{$id}->{wheel}->put( join "\n", @data );
}


# Terminate a DCC connection manually.
sub dcc_close {
  my ($kernel, $heap, $id) = @_[KERNEL, HEAP, ARG0];

  _send_event( $kernel, $heap, 'irc_dcc_done', $id,
	       @{$heap->{dcc}->{$id}}{ qw(nick type port file size done) } );

  if ($heap->{dcc}->{$id}->{wheel}->get_driver_out_octets()) {
    $kernel->delay( _tryclose => .2 => @_[ARG0..$#_] );
    return;
  }

  if (exists $heap->{dcc}->{$id}->{wheel}) {
    delete $heap->{wheelmap}->{$heap->{dcc}->{$id}->{wheel}->ID};
    delete $heap->{dcc}->{$id}->{wheel};
  }
  delete $heap->{dcc}->{$id};
}


# Automatically replies to a PING from the server. Do not confuse this
# with CTCP PINGs, which are a wholly different animal that evolved
# much later on the technological timeline.
sub irc_ping {
  my ($kernel, $arg) = @_[KERNEL, ARG0];

  $kernel->yield( 'sl_login', "PONG $arg" );
}


# The way /notify is implemented in IRC clients.
sub ison {
  my ($kernel, @nicks) = @_[KERNEL, ARG0 .. $#_];
  my $tmp = "ISON";

  die "No nicknames passed to POE::Component::IRC::ison" unless @nicks;

  # We can pass as many nicks as we want, as long as it's shorter than
  # the maximum command length (510). If the list we get is too long,
  # w'll break it into multiple ISON commands.
  while (@nicks) {
    my $nick = shift @nicks;
    if (length($tmp) + length($nick) >= 509) {
      $kernel->yield( 'sl_high', $tmp );
      $tmp = "ISON";
    }
    $tmp .= " $nick";
  }
  $kernel->yield( 'sl_high', $tmp );
}


# Tell the IRC server to forcibly remove a user from a channel.
sub kick {
  my ($kernel, $chan, $nick) = @_[KERNEL, ARG0, ARG1];
  my $message = join '', @_[ARG2 .. $#_];

  unless (defined $chan and defined $nick) {
    die "The POE::Component::IRC event \"kick\" requires at least two arguments";
  }

  $nick .= " :$message" if defined $message;
  $kernel->yield( 'sl_high', "KICK $chan $nick" );
}


# Set up a new IRC component. Doesn't actually create and return an object.
sub new {
  my ($package, $alias) = splice @_, 0, 2;

  unless ($alias) {
    croak "Not enough arguments to POE::Component::IRC::new()";
  }

  my @event_map = map {($_, $irc_commands{$_}->[CMD_SUB])} keys %irc_commands;

  POE::Session->new( @event_map,
		     '_tryclose' => \&dcc_close,
		     $package => [qw( _dcc_failed
				      _dcc_read
				      _dcc_timeout
				      _dcc_up
				      _parseline
				      _sock_down
				      _sock_failed
				      _sock_up
				      _start
				      _stop
				      connect
				      dcc
				      dcc_accept
				      dcc_chat
				      dcc_close
				      irc_ping
				      ison
				      kick
				      register
				      shutdown
				      sl
				      sl_login
				      sl_high
                                      sl_delayed
				      sl_prioritized
				      topic
				      unregister
				      userhost )],
		     [ $alias, @_ ] );
}


# The handler for all IRC commands that take no arguments.
sub noargs {
  my ($kernel, $state, $arg) = @_[KERNEL, STATE, ARG0];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  if (defined $arg) {
    die "The POE::Component::IRC event \"$state\" takes no arguments";
  }
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# The handler for commands that take one required and two optional arguments.
sub oneandtwoopt {
  my ($kernel, $state) = @_[KERNEL, STATE];
  my $arg = join '', @_[ARG0 .. $#_];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  $state = uc $state;
  if (defined $arg) {
    $arg = ':' . $arg if $arg =~ /\s/;
    $state .= " $arg";
  }
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# The handler for commands that take at least one optional argument.
sub oneoptarg {
  my ($kernel, $state) = @_[KERNEL, STATE];
  my $arg = join '', @_[ARG0 .. $#_] if defined $_[ARG0];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  $state = uc $state;
  if (defined $arg) {
    # who command possibly accepts a channel, look up ID
    if( $state eq 'WHO' )
    {
      if( $arg =~ /^[#&+!]/ )
      {
        my ($chan) = $arg =~ m/^[#&+!](.*)$/;
        $arg = $c_lookup{lc($chan)} || $arg;
      }
    }
    $arg = ':' . $arg if $arg =~ /\s/;
    $state .= " $arg";
  }
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# The handler for commands which take one required and one optional argument.
sub oneortwo {
  my ($kernel, $state, $one) = @_[KERNEL, STATE, ARG0];
  my $two = join '', @_[ARG1 .. $#_];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  unless (defined $one) {
    die "The POE::Component::IRC event \"$state\" requires at least one argument";
  }

  # store the channel in our lookup hash
  if( $state eq 'join' )
  {
    my ($pre,$chan) = $one =~ m/^([#&+!])(.*)$/;
    $c_lookup{lc($chan)} = $one;
  }

  $state = uc( $state ) . " $one";
  $state .= " $two" if defined $two;
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# Handler for commands that take exactly one argument.
sub onlyonearg {
  my ($kernel, $state) = @_[KERNEL, STATE];
  my $arg = join '', @_[ARG0 .. $#_];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  unless (defined $arg) {
    die "The POE::Component::IRC event \"$state\" requires one argument";
  }

  $state = uc $state;
  $arg = ':' . $arg if $arg =~ /\s/;
  $state .= " $arg";
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# Handler for commands that take exactly two arguments.
sub onlytwoargs {
  my ($kernel, $state, $one) = @_[KERNEL, STATE, ARG0];
  my ($two) = join '', @_[ARG1 .. $#_];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  unless (defined $one and defined $two) {
    die "The POE::Component::IRC event \"$state\" requires two arguments";
  }

  $state = uc $state;
  # invite command accepts a channel, look up ID 
  if( $state eq 'INVITE' )
  {
    my ($chan) = $two =~ m/^[#&+!](.*)$/;
    $two = $c_lookup{lc($chan)} || $two;
  }
  $two = ':' . $two if $two =~ /\s/;
  $state .= " $one $two";
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# Handler for privmsg or notice events.
sub privandnotice {
  my ($kernel, $state, $to) = @_[KERNEL, STATE, ARG0];
  my $message = join ' ', @_[ARG1 .. $#_];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  $state =~ s/privmsglo/privmsg/;
  $state =~ s/privmsghi/privmsg/;
  $state =~ s/noticelo/notice/;
  $state =~ s/noticehi/notice/;

  unless (defined $to and defined $message) {
    die "The POE::Component::IRC event \"$state\" requires two arguments";
  }

  if( ref $to ne 'ARRAY' ) {
    $to = [ $to ];
  }

  my @targets;
  foreach ( @$to )
  {
      if( /^[#&+!]/ )
      {
        my ($chan) = $_ =~ m/^[#&+!](.*)$/;
        push( @targets, $c_lookup{lc($chan)} || $_ );
      }
      else
      {
        push( @targets, $_ );
      }
  }

  $to = join ',', @targets;

  $state = uc $state;
  $state .= " $to :$message";
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# Ask P::C::IRC to send you certain events, listed in @events.
sub register {
  my ($kernel, $heap, $session, $sender, @events) =
    @_[KERNEL, HEAP, SESSION, SENDER, ARG0 .. $#_];

  die "Not enough arguments" unless @events;

  # FIXME: What "special" event names go here? (ie, "errors")
  # basic, dcc (implies ctcp), ctcp, oper ...what other categories?
  foreach (@events) {
    $_ = "irc_" . $_ unless /^_/;
    $heap->{events}->{$_}->{$sender} = $sender;
    $heap->{sessions}->{$sender}->{'ref'} = $sender;
    unless ($heap->{sessions}->{$sender}->{refcnt}++ or $session == $sender) {
      $kernel->refcount_increment($sender->ID(), PCI_REFCOUNT_TAG);
    }
  }
}


# Tell the IRC session to go away.
sub shutdown {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  foreach ($kernel->alias_list( $_[SESSION] )) {
    $kernel->alias_remove( $_ );
  }

  foreach (qw(socket sock socketfactory dcc wheelmap)) {
    delete $heap->{$_};
  }
}


# Send a line of login-priority IRC output.  These are things which
# must go first.
sub sl_login {
  my ($kernel, $heap) = @_[KERNEL, HEAP];
  my $arg = join '', @_[ARG0 .. $#_];
  $kernel->yield( 'sl_prioritized', PRI_LOGIN, $arg );
}


# Send a line of high-priority IRC output.  Things like channel/user
# modes, kick messages, and whatever.
sub sl_high {
  my ($kernel, $heap) = @_[KERNEL, HEAP];
  my $arg = join '', @_[ARG0 .. $#_];
  $kernel->yield( 'sl_prioritized', PRI_HIGH, $arg );
}


# Send a line of normal-priority IRC output to the server.  PRIVMSG
# and other random chatter.  Uses sl() for compatibility with existing
# code.
sub sl {
  my ($kernel, $heap) = @_[KERNEL, HEAP];
  my $arg = join '', @_[ARG0 .. $#_];

  $kernel->yield( 'sl_prioritized', PRI_NORMAL, $arg );
}


# Prioritized sl().  This keeps the queue ordered by priority, low to
# high in the UNIX tradition.  It also throttles transmission
# following the hybrid ircd's algorithm, so you can't accidentally
# flood yourself off.  Thanks to Raistlin for explaining how ircd
# throttles messages.
sub sl_prioritized {
  my ($kernel, $heap, $priority, $msg) = @_[KERNEL, HEAP, ARG0, ARG1];
  my $now = time();
  $heap->{send_time} = $now if $heap->{send_time} < $now;

  if (@{$heap->{send_queue}}) {
    my $i = @{$heap->{send_queue}};
    $i-- while ($i and $priority < $heap->{send_queue}->[$i-1]->[MSG_PRI]);
    splice( @{$heap->{send_queue}}, $i, 0,
            [ $priority,  # MSG_PRI
              $msg,       # MSG_TEXT
            ]
          );
  } elsif ( $heap->{dont_flood} and
            $heap->{send_time} - $now >= 10 or not defined $heap->{socket}
          ) {
    push( @{$heap->{send_queue}},
          [ $priority,  # MSG_PRI
            $msg,       # MSG_TEXT
	   ]
	 );
    $kernel->delay( sl_delayed => $heap->{send_time} - $now - 10 );
  } else {
    warn ">>> $msg\n" if $heap->{debug};
    $heap->{send_time} += 2 + length($msg) / 120;
    $heap->{socket}->put($msg);
  }
}

# Send delayed lines to the ircd.  We manage a virtual "send time"
# that progresses into the future based on hybrid ircd's rules every
# time a message is sent.  Once we find it ten or more seconds into
# the future, we wait for the realtime clock to catch up.
sub sl_delayed {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  return unless defined $heap->{'socket'};

  my $now = time();
  $heap->{send_time} = $now if $heap->{send_time} < $now;

  while (@{$heap->{send_queue}} and ($heap->{send_time} - $now < 10)) {
    my $arg = (shift @{$heap->{send_queue}})->[MSG_TEXT];
    warn ">>> $arg\n" if $heap->{'debug'};
    $heap->{send_time} += 2 + length($arg) / 120;
    $heap->{'socket'}->put( "$arg" );
  }

  $kernel->delay( sl_delayed => $heap->{send_time} - $now - 10 )
    if @{$heap->{send_queue}};
}


# The handler for commands which have N arguments, separated by spaces.
sub spacesep {
  my ($kernel, $state, @args) = @_[KERNEL, STATE, ARG0 .. $#_ ];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  local $" = " ";
  $state = uc $state;
  $state .= " @args" if @args;
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# The handler for the 'mode' command
sub mode {
  my ($kernel, $state, @args) = @_[KERNEL, STATE, ARG0 .. $#_ ];
  my $pri = $irc_commands{$state}->[CMD_PRI];

  $state = uc $state;

  # first argument is always the channel or target to affect
  if( @args < 1 )
  {
    die "The POE::Component::IRC event \"$state\" requires one argument";
  }

  # compatibility with documentation, accept the entire arguments as a single
  # string [ie, mode( '#topgamers +ntrpzl 5' ) ];
  if( $args[0] =~ / / )
  {
    @args = split(/ /,$args[0]);
  }

  # are we targeting a channel? if so, fetch the ID
  if( $args[0] =~ /^[#&+!]/ )
  {
    my ($chan) = $args[0] =~ m/^[#&+!](.*)$/;
    $args[0] = $c_lookup{lc($chan)} || $args[0];
  }

  local $" = " ";
  $state .= " @args" if @args;
  $kernel->yield( 'sl_prioritized', $pri, $state );
}


# Set or query the current topic on a channel.
sub topic {
  my ($kernel, $chan) = @_[KERNEL, ARG0];
  my $topic = join '', @_[ARG1 .. $#_];

  $chan .= " :$topic" if length $topic;
  $kernel->yield( 'sl_prioritized', PRI_NORMAL, "TOPIC $chan" );
}


# Ask P::C::IRC to stop sending you certain events, listed in $evref.
sub unregister {
  my ($kernel, $heap, $session, $sender, @events) =
    @_[KERNEL,  HEAP, SESSION,  SENDER,  ARG0 .. $#_];

  die "Not enough arguments" unless @events;

  foreach (@events) {
    delete $heap->{events}->{$_}->{$sender};
    if (--$heap->{sessions}->{$sender}->{refcnt} <= 0) {
      delete $heap->{sessions}->{$sender};
      unless ($session == $sender) {
        $kernel->refcount_decrement($sender->ID(), PCI_REFCOUNT_TAG);
      }
    }
  }
}


# Asks the IRC server for some random information about particular nicks.
sub userhost {
  my ($kernel, @nicks) = @_[KERNEL, ARG0 .. $#_];
  my @five;

  die "No nicknames passed to POE::Component::IRC::userhost" unless @nicks;

  # According to the RFC, you can only send 5 nicks at a time.
  while (@nicks) {
    $kernel->yield( 'sl_prioritized', PRI_HIGH,
		    "USERHOST " . join(' ', splice(@nicks, 0, 5)) );
  }
}



1;
__END__

=head1 NAME

POE::Component::IRC - a fully event-driven IRC client module.

=head1 SYNOPSIS

  use POE::Component::IRC;

  # Do this when you create your sessions. 'my client' is just a
  # kernel alias to christen the new IRC connection with. (Returns
  # only a true or false success flag, not an object.)
  POE::Component::IRC->new('my client') or die "Oh noooo! $!";

  # Do stuff like this from within your sessions. This line tells the
  # connection named "my client" to send your session the following
  # events when they happen.
  $kernel->post('my client', 'register', qw(connected msg public cdcc cping));
  # You can guess what this line does.
  $kernel->post('my client', 'connect',
	        { Nick     => 'Boolahman',
		  Server   => 'irc-w.primenet.com',
		  Port     => 6669,
		  Username => 'quetzal',
		  Ircname  => 'Ask me about my colon!', } );

=head1 DESCRIPTION

POE::Component::IRC is a POE component (who'd have guessed?) which
acts as an easily controllable IRC client for your other POE
components and sessions. You create an IRC component and tell it what
events your session cares about and where to connect to, and it sends
back interesting IRC events when they happen. You make the client do
things by sending it events. That's all there is to it. Cool, no?

[Note that using this module requires some familiarity with the
details of the IRC protocol. I'd advise you to read up on the gory
details of RFC 1459
E<lt>http://cs-pub.bu.edu/pub/irc/support/rfc1459.txtE<gt> before you
get started. Keep the list of server numeric codes handy while you
program. Needless to say, you'll also need a good working knowledge of
POE, or this document will be of very little use to you.]

So you want to write a POE program with POE::Component::IRC? Listen
up. The short version is as follows: Create your session(s) and an
alias for a new POE::Component::IRC client. (Conceptually, it helps if
you think of them as little IRC clients.) In your session's _start
handler, send the IRC client a 'register' event to tell it which IRC
events you want to receive from it. Send it a 'connect' event at some
point to tell it to join the server, and it should start sending you
interesting events every once in a while. If you want to tell it to
perform an action, like joining a channel and saying something witty,
send it the appropriate events like so:

  $kernel->post( 'my client', 'join', '#perl' );
  $kernel->post( 'my client', 'privmsg', '#perl', 'Pull my finger!' );

The long version is the rest of this document.

=head1 METHODS

Well, OK, there's only actually one, so it's more like "METHOD".

=over

=item new

Takes one argument: a name (kernel alias) which this new connection
will be known by. B<WARNING:> This method, for all that it's named
"new" and called in an OO fashion, doesn't actually return an
object. It returns a true or false value which indicates if the new
session was created or not. If it returns false, check $! for the
POE::Session error code.

=back

=head1 INPUT

How to talk to your new IRC component... here's the events we'll accept.

=head2 Important Commands

=over

=item connect

Takes one argument: a hash reference of attributes for the new
connection (see the L<SYNOPSIS> section of this doc for an
example). This event tells the IRC client to connect to a
new/different server. If it has a connection already open, it'll close
it gracefully before reconnecting. Possible attributes for the new
connection are "Server", the server name; "Password", an optional
password for restricted servers; "Port", the remote port number,
"LocalAddr", which local IP address on a multihomed box to connect as;
"LocalPort", the local TCP port to open your socket on; "Nick", your
client's IRC nickname; "Username", your client's username; and
"Ircname", some cute comment or something. C<connect()> will supply
reasonable defaults for any of these attributes which are missing, so
don't feel obliged to write them all out.

=item ctcp and ctcpreply

Sends a CTCP query or response to the nick(s) or channel(s) which you
specify. Takes 2 arguments: the nick or channel to send a message to
(use an array reference here to specify multiple recipients), and the
plain text of the message to send (the CTCP quoting will be handled
for you).

=item dcc

Send a DCC SEND or CHAT request to another person. Takes at least two
arguments: the nickname of the person to send the request to and the
type of DCC request (SEND or CHAT). For SEND requests, be sure to add
a third argument for the filename you want to send. Optionally, you
can add a fourth argument for the DCC transfer blocksize, but the
default of 1024 should usually be fine.

Incidentally, you can send other weird nonstandard kinds of DCCs too;
just put something besides 'SEND' or 'CHAT' (say, "FOO") in the type
field, and you'll get back "irc_dcc_foo" events when activity happens
on its DCC connection.

=item dcc_accept

Accepts an incoming DCC connection from another host. First argument:
the magic cookie from an 'irc_dcc_request' event. In the case of a DCC
GET, the second argument can optionally specify a new name for the
destination file of the DCC transfer, instead of using the sender's name
for it. (See the 'irc_dcc_request' section below for more details.)

=item dcc_chat

Sends lines of data to the person on the other side of a DCC CHAT
connection. Takes any number of arguments: the magic cookie from an
'irc_dcc_start' event, followed by the data you wish to send. (It'll be
chunked into lines by a POE::Filter::Line for you, don't worry.)

=item dcc_close

Terminates a DCC SEND or GET connection prematurely, and causes DCC CHAT
connections to close gracefully. Takes one argument: the magic cookie
from an 'irc_dcc_start' or 'irc_dcc_request' event.

=item join

Tells your IRC client to join a single channel of your choice. Takes
at least one arg: the channel name (required) and the channel key
(optional, for password-protected channels).

=item kick

Tell the IRC server to forcibly evict a user from a particular
channel. Takes at least 2 arguments: a channel name, the nick of the
user to boot, and an optional witty message to show them as they sail
out the door.

=item mode

Request a mode change on a particular channel or user. Takes at least
one argument: the mode changes to effect, as a single string (e.g.,
"+sm-p+o"), and any number of optional operands to the mode changes
(nicks, hostmasks, channel keys, whatever.) Or just pass them all as one
big string and it'll still work, whatever. I regret that I haven't the
patience now to write a detailed explanation, but serious IRC users know
the details anyhow.

=item nick

Allows you to change your nickname. Takes exactly one argument: the
new username that you'd like to be known as.

=item notice

Sends a NOTICE message to the nick(s) or channel(s) which you
specify. Takes 2 arguments: the nick or channel to send a notice to
(use an array reference here to specify multiple recipients), and the
text of the notice to send.

=item part

Tell your IRC client to leave the channels which you pass to it. Takes
any number of arguments: channel names to depart from.

=item privmsg

Sends a public or private message to the nick(s) or channel(s) which
you specify. Takes 2 arguments: the nick or channel to send a message
to (use an array reference here to specify multiple recipients), and
the text of the message to send.

=item quit

Tells the IRC server to disconnect you. Takes one optional argument:
some clever, witty string that other users in your channels will see
as you leave. You can expect to get an C<irc_disconnect> event shortly
after sending this.

=item register

Takes N arguments: a list of event names that your session wants to
listen for, minus the "irc_" prefix. So, for instance, if you just
want a bot that keeps track of which people are on a channel, you'll
need to listen for JOINs, PARTs, QUITs, and KICKs to people on the
channel you're in. You'd tell POE::Component::IRC that you want those
events by saying this:

  $kernel->post( 'my client', 'register', qw(join part quit kick) );

Then, whenever people enter or leave a channel your bot is on (forcibly
or not), your session will receive events with names like "irc_join",
"irc_kick", etc., which you can use to update a list of people on the
channel.

Registering for C<'all'> will cause it to send all IRC-related events to
you; this is the easiest way to handle it. See the test script for an
example.

=item shutdown

By default, POE::Component::IRC sessions never go away. Even after
they're disconnected, they're still sitting around in the background,
waiting for you to call C<connect()> on them again to reconnect.
(Whether this behavior is the Right Thing is doubtful, but I don't want
to break backwards compatibility at this point.) You can send the IRC
session a C<shutdown> event manually to make it delete itself.

=item unregister

Takes N arguments: a list of event names which you I<don't> want to
receive. If you've previously done a 'register' for a particular event
which you no longer care about, this event will tell the IRC
connection to stop sending them to you. (If you haven't, it just
ignores you. No big deal.)

=back

=head2 Not-So-Important Commands

=over

=item admin

Asks your server who your friendly neighborhood server administrators
are. If you prefer, you can pass it a server name to query, instead of
asking the server you're currently on.

=item away

When sent with an argument (a message describig where you went), the
server will note that you're now away from your machine or otherwise
preoccupied, and pass your message along to anyone who tries to
communicate with you. When sent without arguments, it tells the server
that you're back and paying attention.

=item info

Basically the same as the "version" command, except that the server is
permitted to return any information about itself that it thinks is
relevant. There's some nice, specific standards-writing for ya, eh?

=item invite

Invites another user onto an invite-only channel. Takes 2 arguments:
the nick of the user you wish to admit, and the name of the channel to
invite them to.

=item ison

Asks the IRC server which users out of a list of nicknames are
currently online. Takes any number of arguments: a list of nicknames
to query the IRC server about.

=item links

Asks the server for a list of servers connected to the IRC
network. Takes two optional arguments, which I'm too lazy to document
here, so all you would-be linklooker writers should probably go dig up
the RFC.

=item list

Asks the server for a list of visible channels and their topics. Takes
any number of optional arguments: names of channels to get topic
information for. If called without any channel names, it'll list every
visible channel on the IRC network. This is usually a really big list,
so don't do this often.

=item motd

Request the server's "Message of the Day", a document which typically
contains stuff like the server's acceptable use policy and admin
contact email addresses, et cetera. Normally you'll automatically
receive this when you log into a server, but if you want it again,
here's how to do it. If you'd like to get the MOTD for a server other
than the one you're logged into, pass it the server's hostname as an
argument; otherwise, no arguments.

=item names

Asks the server for a list of nicknames on particular channels. Takes
any number of arguments: names of channels to get lists of users
for. If called without any channel names, it'll tell you the nicks of
everyone on the IRC network. This is a really big list, so don't do
this much.

=item sl

Sends a raw line of text to the server. Takes one argument: a string
of a raw IRC command to send to the server. It is more optimal to use
the events this module supplies instead of writing raw IRC commands
yourself.

=item stats

Returns some information about a server. Kinda complicated and not
terribly commonly used, so look it up in the RFC if you're
curious. Takes as many arguments as you please.

=item time

Asks the server what time it thinks it is, which it will return in a
human-readable form. Takes one optional argument: a server name to
query. If not supplied, defaults to current server.

=item topic

Retrieves or sets the topic for particular channel. If called with just
the channel name as an argument, it will ask the server to return the
current topic. If called with the channel name and a string, it will
set the channel topic to that string.

=item trace

If you pass a server name or nick along with this request, it asks the
server for the list of servers in between you and the thing you
mentioned. If sent with no arguments, it will show you all the servers
which are connected to your current server.

=item userhost

Asks the IRC server for information about particular nicknames. (The
RFC doesn't define exactly what this is supposed to return.) Takes any
number of arguments: the nicknames to look up.

=item users

Asks the server how many users are logged into it. Defaults to the
server you're currently logged into; however, you can pass a server
name as the first argument to query some other machine instead.

=item version

Asks the server about the version of ircd that it's running. Takes one
optional argument: a server name to query. If not supplied, defaults
to current server.

=item who

Lists the logged-on users matching a particular channel name, hostname,
nickname, or what-have-you. Takes one optional argument: a string for
it to search for. Wildcards are allowed; in the absence of this
argument, it will return everyone who's currently logged in (bad
move). Tack an "o" on the end if you want to list only IRCops, as per
the RFC.

=item whois

Queries the IRC server for detailed information about a particular
user. Takes any number of arguments: nicknames or hostmasks to ask for
information about.

=item whowas

Asks the server for information about nickname which is no longer
connected. Takes at least one argument: a nickname to look up (no
wildcards allowed), the optional maximum number of history entries to
return, and the optional server hostname to query.

=back

=head2 Purely Esoteric Commands

=over

=item oper

In the exceedingly unlikely event that you happen to be an IRC
operator, you can use this command to authenticate with your IRC
server. Takes 2 arguments: your username and your password.

=item rehash

Tells the IRC server you're connected to to rehash its configuration
files. Only useful for IRCops. Takes no arguments.

=item restart

Tells the IRC server you're connected to to shut down and restart itself.
Only useful for IRCops, thank goodness. Takes no arguments.

=item sconnect

Tells one IRC server (which you have operator status on) to connect to
another. This is actually the CONNECT command, but I already had an
event called 'connect', so too bad. Takes the args you'd expect: a
server to connect to, an optional port to connect on, and an optional
remote server to connect with, instead of the one you're currently on.

=item summon

Don't even ask.

=item wallops

Another opers-only command. This one sends a message to all currently
logged-on opers (and +w users); sort of a mass PA system for the IRC
server administrators. Takes one argument: some clever, witty message
to send.

=back

=head1 OUTPUT

The events you will receive (or can ask to receive) from your running
IRC component. Note that all incoming event names your session will
receive are prefixed by "irc_", to inhibit event namespace pollution.

If you wish, you can ask the client to send you every event it
generates. Simply register for the event name "all". This is a lot
easier than writing a huge list of things you specifically want to
listen for. FIXME: I'd really like to classify these somewhat
("basic", "oper", "ctcp", "dcc", "raw" or some such), and I'd welcome
suggestions for ways to make this easier on the user, if you can think
of some.

=head2 Important Events

=over

=item irc_connected

The IRC component will send an "irc_connected" event as soon as it
establishes a connection to an IRC server, before attempting to log
in. ARG0 is the server name.

B<NOTE:> When you get an "irc_connected" event, this doesn't mean you
can start sending commands to the server yet. Wait until you receive
an irc_001 event (the server welcome message) before actually sending
anything back to the server.

=item irc_ctcp_*

irc_ctcp_whatever events are generated upon receipt of CTCP messages.
For instance, receiving a CTCP PING request generates an irc_ctcp_ping
event, CTCP ACTION (produced by typing "/me" in most IRC clients)
generates an irc_ctcp_action event, blah blah, so on and so forth. ARG0
is the nick!hostmask of the sender. ARG1 is the channel/recipient
name(s). ARG2 is the text of the CTCP message.

Note that DCCs are handled separately -- see the 'irc_dcc_request'
event, below.

=item irc_ctcpreply_*

irc_ctcpreply_whatever messages are just like irc_ctcp_whatever
messages, described above, except that they're generated when a response
to one of your CTCP queries comes back. They have the same arguments and
such as irc_ctcp_* events.

=item irc_disconnected

The counterpart to irc_connected, sent whenever a socket connection
to an IRC server closes down (whether intentionally or
unintentionally). ARG0 is the server name.

=item irc_error

You get this whenever the server sends you an ERROR message. Expect
this to usually be accompanied by the sudden dropping of your
connection. ARG0 is the server's explanation of the error.

=item irc_join

Sent whenever someone joins a channel that you're on. ARG0 is the
person's nick!hostmask. ARG1 is the channel name.

=item irc_invite

Sent whenever someone offers you an invitation to another channel. ARG0
is the person's nick!hostmask. ARG1 is the name of the channel they want
you to join.

=item irc_kick

Sent whenever someone gets booted off a channel that you're on. ARG0
is the kicker's nick!hostmask. ARG1 is the channel name. ARG2 is the
nick of the unfortunate kickee. ARG3 is the explanation string for the
kick.

=item irc_mode

Sent whenever someone changes a channel mode in your presence, or when
you change your own user mode. ARG0 is the nick!hostmask of that
someone. ARG1 is the channel it affects (or your nick, if it's a user
mode change). ARG2 is the mode string (i.e., "+o-b"). The rest of the
args (ARG3 .. $#_) are the operands to the mode string (nicks,
hostmasks, channel keys, whatever).

=item irc_msg

Sent whenever you receive a PRIVMSG command that was addressed to you
privately. ARG0 is the nick!hostmask of the sender. ARG1 is an array
reference containing the nick(s) of the recipients. ARG2 is the text
of the message.

=item irc_nick

Sent whenever you, or someone around you, changes nicks. ARG0 is the
nick!hostmask of the changer. ARG1 is the new nick that they changed
to.

=item irc_notice

Sent whenever you receive a NOTICE command. ARG0 is the nick!hostmask
of the sender. ARG1 is an array reference containing the nick(s) or
channel name(s) of the recipients. ARG2 is the text of the NOTICE
message.

=item irc_part

Sent whenever someone leaves a channel that you're on. ARG0 is the
person's nick!hostmask. ARG1 is the channel name.

=item irc_ping

An event sent whenever the server sends a PING query to the
client. (Don't confuse this with a CTCP PING, which is another beast
entirely. If unclear, read the RFC.) Note that POE::Component::IRC will
automatically take care of sending the PONG response back to the
server for you, although you can still register to catch the event for
informational purposes.

=item irc_public

Sent whenever you receive a PRIVMSG command that was sent to a
channel. ARG0 is the nick!hostmask of the sender. ARG1 is an array
reference containing the channel name(s) of the recipients. ARG2 is
the text of the message.

=item irc_quit

Sent whenever someone on a channel with you quits IRC (or gets
KILLed). ARG0 is the nick!hostmask of the person in question. ARG1 is
the clever, witty message they left behind on the way out.

=item irc_socketerr

Sent when a connection couldn't be established to the IRC server. ARG0
is probably some vague and/or misleading reason for what failed.

=item All numeric events (see RFC 1459)

Most messages from IRC servers are identified only by three-digit
numeric codes with undescriptive constant names like RPL_UMODEIS and
ERR_NOTOPLEVEL. (Actually, the list of codes in the RFC is kind of
out-of-date... the list in the back of Net::IRC::Event.pm is more
complete, and different IRC networks have different and incompatible
lists. Ack!) As an example, say you wanted to handle event 376
(RPL_ENDOFMOTD, which signals the end of the MOTD message). You'd
register for '376', and listen for 'irc_376' events. Simple, no? ARG0
is the name of the server which sent the message. ARG1 is the text of
the message.

=back

=head2 Somewhat Less Important Events

=over

=item irc_dcc_chat

Notifies you that one line of text has been received from the
client on the other end of a DCC CHAT connection. ARG0 is the
connection's magic cookie, ARG1 is the nick of the person on the other
end, ARG2 is the port number, and ARG3 is the text they sent.

=item irc_dcc_done

You receive this event when a DCC connection terminates normally.
Abnormal terminations are reported by "irc_dcc_error", below. ARG0 is
the connection's magic cookie, ARG1 is the nick of the person on the
other end, ARG2 is the DCC type (CHAT, SEND, GET, etc.), and ARG3 is the
port number. For DCC SEND and GET connections, ARG4 will be the
filename, ARG5 will be the file size, and ARG6 will be the number of
bytes transferred. (ARG5 and ARG6 should always be the same.)

=item irc_dcc_error

You get this event whenever a DCC connection or connection attempt
terminates unexpectedly or suffers some fatal error. ARG0 will be the
connection's magic cookie, ARG1 will be a string describing the error.
ARG2 will be the nick of the person on the other end of the connection.
ARG3 is the DCC type (SEND, GET, CHAT, etc.). ARG4 is the port number of
the DCC connection, if any. For SEND and GET connections, ARG5 is the
filename, ARG6 is the expected file size, and ARG7 is the transfered size.

=item irc_dcc_get

Notifies you that another block of data has been successfully
transferred from the client on the other end of your DCC GET connection.
ARG0 is the connection's magic cookie, ARG1 is the nick of the person on
the other end, ARG2 is the port number, ARG3 is the filename, ARG4 is
the total file size, and ARG5 is the number of bytes successfully
transferred so far.

=item irc_dcc_request

You receive this event when another IRC client sends you a DCC SEND or
CHAT request out of the blue. You can examine the request and decide
whether or not to accept it here. ARG0 is the nick of the client on the
other end. ARG1 is the type of DCC request (CHAT, SEND, etc.). ARG2 is
the port number. ARG3 is a "magic cookie" argument, suitable for sending
with 'dcc_accept' events to signify that you want to accept the
connection (see the 'dcc_accept' docs). For DCC SEND and GET
connections, ARG4 will be the filename, and ARG5 will be the file size.

=item irc_dcc_send

Notifies you that another block of data has been successfully
transferred from you to the client on the other end of a DCC SEND
connection. ARG0 is the connection's magic cookie, ARG1 is the nick of
the person on the other end, ARG2 is the port number, ARG3 is the
filename, ARG4 is the total file size, and ARG5 is the number of bytes
successfully transferred so far.

=item irc_dcc_start

This event notifies you that a DCC connection has been successfully
established. ARG0 is a unique "magic cookie" argument which you can pass
to 'dcc_chat' or 'dcc_close'. ARG1 is the nick of the person on the
other end, ARG2 is the DCC type (CHAT, SEND, GET, etc.), and ARG3 is the
port number. For DCC SEND and GET connections, ARG4 will be the filename
and ARG5 will be the file size.

=item irc_snotice

A weird, non-RFC-compliant message from an IRC server. Don't worry
about it. ARG0 is the text of the server's message.

=back

=head1 AUTHOR

Dennis Taylor, E<lt>dennis@funkplanet.comE<gt>

=head1 MAD PROPS

The maddest of mad props go out to Rocco "dngor" Caputo
E<lt>troc@netrus.netE<gt>, for inventing something as mind-bogglingly
cool as POE, and to Kevin "oznoid" Lenzo E<lt>lenzo@cs.cmu.eduE<gt>,
for being the attentive parent of our precocious little infobot on
#perl.

Further props to a few of the studly bughunters who made this module not
suck: Abys <abys@web1-2-3.com>, Addi <addi@umich.edu>, ResDev
<ben@reser.org>, and Roderick <roderick@argon.org>. Woohoo!

=head1 SEE ALSO

RFC 1459, http://www.irchelp.org/, http://poe.perl.org/,
http://www.infobot.org/,
http://newyork.citysearch.com/profile?fid=2&id=7104760


=cut
