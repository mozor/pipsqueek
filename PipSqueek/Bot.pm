package PipSqueek::Bot;

use strict;
use warnings;

use XML::Simple;
#use Data::Dumper;


# General Application Routines:
sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	
	my $self = {};
	my $args = shift;
	
	$self->{'file'} = $args->{'file'};
	# the file we load our bot settings from

	$self->{'kernel'} = $args->{'kernel'};
	# an instance of a POE::Kernel object

	$self->{'handler_registry'} = $args->{'handler_registry'};
	# the handlers our bot uses 
	# (this is bad design imo, but there's no way around it..)

	bless($self,$class);

	$self->load();

	return $self;
}


sub load
# loads our bot settings from an XML file and stores them in our settings hash
{
	my $self = shift;
	$self->{'_settings'} = XMLin( $self->{'file'} )->{'settings'} 
	or die "Could not load settings from file '" . $self->{'file'} . "': $!\n";

	return 1;
}


sub save
# saves our bot settings back into their file
{
	my $self = shift;
	my $hash = {};
	$hash->{'settings'} = $self->{'_settings'};
	# we construct the temporary hash here so that the XML output is more human-readable
	XMLout( $hash, outputfile => $self->{'file'} ) 
	or die "Could not save settings to file '" . $self->{'file'} . "': $!\n";

	return 1;
}


sub param
# a general accessor/mutator for the settings hash
# borrowed from CGI::Application
{
	my $self = shift;
	my (@data) = (@_);

	$self->{'_settings'} = {} unless (exists($self->{'_settings'}));
	# create the hash if it doesn't exist

	my $params = $self->{'_settings'};

	if (scalar(@data)) 
	{ # If data is provided, set it!
		if ( ref($data[0]) eq 'HASH' ) 
		{ # Is it a hash, or hash-ref?
			%$params = (%$params, %{$data[0]});
			# Make a copy, which augments the existing contents (if any)
		}
		elsif ((scalar(@data) % 2) == 0) 
		{ # It appears to be a possible hash (even number of elements)
			%$params = (%$params, @data);
		}
		elsif (scalar(@data) > 1) {
			die "Odd number of elements passed to param().";
		}
	} else {
		return (keys(%$params));
	}

	if (scalar(@data) <= 2) 
	{ # If exactly one parameter was sent to param(), return the value
		my $param = $data[0];
		return $params->{$param};
	}

	return; # Otherwise, return undef 
}


sub connect_options
# returns a hash of the connection values for PoCo::IRC
# these should all be self-explanatory
{
	my $self = shift;
	my $opts = {};

	$opts->{'Server'}	= $self->param('server_address') || die "Must specify IRC server";
	$opts->{'Port'}		= $self->param('server_port') || 6667;
	$opts->{'Password'}	= $self->param('server_password') || undef;
	$opts->{'LocalAddr'}= $self->param('local_address') || undef;
	$opts->{'LocalPort'}= $self->param('local_port') || undef;
	$opts->{'Nick'}		= $self->param('nickname') || die "Must specify nickname";
	$opts->{'Username'}	= $self->param('username') || $opts->{'Nick'};
	$opts->{'Ircname'}	= $self->param('ircname')  || $self->version();
	$opts->{'Debug'}	= 0;	# change to 1 to have PoCo::IRC spit out all the text that 
								# gets sent to/from the IRC server

	return $opts;
}


sub version
# returns a string containing version information for the bot
{
	return "PipSqueek v3.1 - http://pipsqueek.l8nite.net/";
}


sub enemies
# returns the list of bot enemies
{
	my $self = shift;
	my $eref = $self->{'kernel'}->get_active_session()->get_heap()->{'enemies'};
	return $eref if defined($eref);
	return undef;
}


sub uptime
# return how long the bot has been running
{
	my $self = shift;
	return( time() - $self->{'kernel'}->get_active_session()->get_heap()->{'start_time'} );
}


sub is_shutdown
# returns the heap's shutdown flag
{
	my $self = shift;
	return $self->{'kernel'}->get_active_session()->get_heap()->{'shutdown'} || 0;
}


sub handler_registry
{
	my $self = shift;
	return $self->{'handler_registry'};
}


# PoCo::IRC Convenience Utilities

sub ban 
# bans a user from the channel
{ 
	my $self = shift;
	my $nick = shift;
	my $chan = $self->param('channel');
	my $type = shift || 1;

	if( $type == 1 )
	{
		$self->mode( $chan, '+b', "*${nick}!*\@*" );
	}
	elsif( $type == 2 )
	{
		my $host = shift || die "Type 2 ban requested, but no host specified";
		$self->mode( $chan, '+b', "*!*\@$host" );
	}
}


sub chanmsg 
# sends a privmsg to the channel
{
	my $self = shift;
	$self->privmsg( $self->param('channel'), shift );
}


sub connect
{
	my $self = shift;
	$self->{'kernel'}->post( 'pipsqueek', 'connect', $self->connect_options() );
}


sub ctcp 
# sends a CTCP to the target channel/user
{ 
	my $self = shift;
	$self->{'kernel'}->post( 'pipsqueek', 'ctcp', shift, shift );
}


sub ctcpreply 
# the same as CTCP except this is sent as a reply (different quoting /me thinks)
{
	my $self = shift;
	$self->{'kernel'}->post( 'pipsqueek', 'ctcpreply', shift, shift );
}


sub kick 
# removes a user from the channel forcibly
{
	my $self = shift;
	$self->{'kernel'}->post( 'pipsqueek', 'kick', $self->param('channel'), shift, shift );
}


sub join 
# makes the bot join a channel, if no channel specified, join default channel
{
	my $self = shift;
	$self->{'kernel'}->post( 'pipsqueek', 'join', shift || $self->param('channel') );
}


sub mode 
# sets a mode on ourself or the channel specified
{ 
	my $self = shift;
	my $mode = shift;
	if( $mode =~ /^[\+\-]/ ) 
	{ # If the first param was a mode, set it on ourself
		$self->{'kernel'}->post( 'pipsqueek', 'mode', $self->param('nickname'), $mode, shift );
	}
	elsif( $mode =~ /^#/ ) 
	{ # they specified a channel, so set it on there
		my $chan = $mode;
		my $mode = shift;
		$self->{'kernel'}->post( 'pipsqueek', 'mode', $chan, $mode, shift );
	}
}


sub nick 
# change our nickname to a new nickname (or if none specified, to our original)
{
	my $self = shift;
	my $nick = shift || $self->param('nickname');
	$self->{'kernel'}->post( 'pipsqueek', 'nick', $nick );
}


sub notice
# notice a target with a message
{
	my $self = shift;
	my $dest = shift;
	my $msg = shift;
	$self->{'kernel'}->post( 'pipsqueek', 'notice', $dest, $msg );
}


sub part 
# leave a channel, if no channel specified, leave our default channel
# with an optional part message (or default part message)
{
	my $self = shift;
	my $dpm = $self->param('part_message') || $self->version(); # default part message
	my $chan = $self->param('channel');
	
	my (@data) = @_ || ();

	if( scalar(@data) == 0 )
	{ # They sent no options at all, part with the default part message and the default channel
		$self->{'kernel'}->post( 'pipsqueek', 'part', $chan, $dpm );
	}
	elsif( scalar(@data) == 1 )
	{ # just sent us a part message, or a channel to leave with default part message
		if( $data[0] =~ /^#/ )
		{ # it was a channel, so leave with the default part message
			$self->{'kernel'}->post( 'pipsqueek', 'part', $data[0], $dpm );
		} 
		else 
		{ # it was a part message, so leave the default channel with this msg
			$self->{'kernel'}->post( 'pipsqueek', 'part', $chan, $data[0] );
		}
	}
	elsif( scalar(@data) == 2 )
	{ # Sent us a channel and a part message, leave with those
		$self->{'kernel'}->post( 'pipsqueek', 'part', $data[0], $data[1] );
	}
	else
	{
		@data = map { $_ = "'$_'"; } @data;
		warn "Invalid options sent to part: @data";
	}
}


sub privmsg 
# sends a private message to the target destination
{
	my $self = shift;
	my $dest = shift;
	my $msg = shift;
	$self->{'kernel'}->post( 'pipsqueek', 'privmsg', $dest, $msg );
}


sub quit 
# leaves the server with an optional quit message (or default quit message)
{
	my $self = shift;
	my $qm = $self->version();
	$self->{'kernel'}->post( 'pipsqueek', 'quit', shift || $self->param('quit_message') || $qm );
}


sub raw { (shift)->{'kernel'}->post( 'pipsqueek', 'sl', shift ); }
# sends the rawcode to the server on the bot's behalf


sub shutdown
# shuts the bot down (well, not really - posts a quit message and sets a flag in the heap)
# It's up to the irc_quit handler to exit the program gracefully
{
	my $self = shift;
	my $qmsg = shift || $self->param('quit_message') || $self->version();
	$self->{'kernel'}->get_active_session()->get_heap()->{'shutdown'} = 1;
	$self->quit( $qmsg );
}


sub topic 
# changes the topic in the channel
{ 
	my $self = shift;
	my $chan = $self->param('channel');
	$self->{'kernel'}->post( 'pipsqueek', 'topic', $chan, shift );
}


1; # module loaded successfully

