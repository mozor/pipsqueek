package PipSqueek::Plugin;
use strict;

use Data::Dumper;
use File::Spec::Functions;

use PipSqueek::Message;

our ($Kernel, $UserDB, $UMapID, $CWD);

# Constructor
sub new
{
	my $proto = shift;
	my $self  = bless( {}, ref($proto) || $proto );

	unless( $Kernel && $CWD ) { ($Kernel,$CWD) = @_; }

	return $self;
}

# some useful mutators for our class data
sub kernel { $Kernel = $_[1] || $Kernel; return $Kernel; }
sub cwd    { $CWD    = $_[1] || $CWD;    return $CWD;    }
sub userdb { $UserDB = $_[1] || $UserDB; return $UserDB; }
sub umapid { $UMapID = $_[1] || $UMapID; return $UMapID ||= {}; }
sub nickname {
	return (shift)->config()->param('identity_nickname');
}

# accessors that return variables from the main program (ick)
sub config  { return $::CONFIGURATION }
sub version { return $::VERSION       }

# Mutator for the event handlers that our plugin will support
#
# TODO: The handler names can be regexes that will be matched against the 
# current IRC message and if successful will be called.  
#
# The value of the key should be the name of a method object in the class
sub plugin_handlers 
{
	my $s = shift; 
	return $s->_merge( $s->{'_handlers'} ||= {}, @_ ); 
}

# should be overridden by the plugin subclass
sub plugin_initialize {}
sub plugin_teardown   {}



# Convenience functions for plugin writers
sub is_command
{
	my ($self,$message) = @_;

	my $c = $self->config();
	my $prefixed = $c->param('public_command_prefix');
	my $nickname = $c->param('identity_nickname');
	my $c_answer = $c->param('answer_when_addressed');

	my $command = undef;
	my $input = $message->message();

	# !quote
	if( $prefixed && $input =~ /^$prefixed/i )
	{
		$input =~ s/^$prefixed//i;
		($command) = split(/ /,$input);
	}
	# PipSqueek: !quote, or PipSqueek: quote
	elsif( $c_answer && $input =~ /^$nickname:/ )
	{
		$input =~ s/^$nickname:\s*//i;
		($command) = split(/ /,$input);
		$command =~ s/^$prefixed//;
	}
	elsif( $message->event() eq 'irc_msg' )
	{ # quote (privmsg only)
		($command) = split(/ /,$input);
	}

	return $command;
}


# Bans a user from the channel
# TODO, this is b0rk until we get the ident stuff straightened
sub ban 
{
	my ($self,$channel,$nick,$type) = (@_);
	my $user = $self->find_user($nick);

	# default ban type
	$type ||= $self->config()->param('default_ban_type') || 4;

	my ($ident,$host) = ($user->{'ident'}, $user->{'hostname'});

	# can only ban on nickname if that's all we know about the user
	unless( defined $ident && defined $host )
	{
		$type = 1;
	}

	my $ban;
	foreach ( $type )
	{
		   if( /1/ ) { $ban = qq(*$nick!*\@*) }
		elsif( /2/ ) { $ban = qq(*!*$ident\@*) }
		elsif( /3/ ) { $ban = qq(*$nick!*$ident\@*) }
		elsif( /4/ ) {
			$host =~ s/^.*?\./*./;
			$ban = qq(*!*\@$host);
		}
		elsif( /5/ ) {
			$host =~ s/^.*?\./*./;
			$ban = qq(*$nick!*\@$host);
		}
		elsif( /6/ ) {
			$host =~ s/^.*?\./*./;
			$ban = qq(*!*$ident\@$host);
		}
		elsif( /7/ ) {
			$host =~ s/^.*?\./*./;
			$ban = qq(*$nick!*$ident\@$host);
		}
	}

	$self->mode( $channel, '+b', $ban );

	return 1;
}

# sends a privmsg to the channel
sub chanmsg
{
	my $self = shift;
	my $chan = $self->config()->param('server_channel');
	return $self->privmsg( $chan, @_ );
}

# sends a CTCP to the target channel/user
sub ctcp      { (shift)->kernel()->post( 'pipsqueek', 'ctcp',      @_ ); }
# the same as CTCP except this is sent as a reply (different quoting)
sub ctcpreply { (shift)->kernel()->post( 'pipsqueek', 'ctcpreply', @_ ); }
# makes the bot join a channel
sub join      { (shift)->kernel()->post( 'pipsqueek', 'join',      @_ ); }
# removes a user from the channel forcibly
sub kick 
{
	my ($self,$channel,$target,$kickmsg) = @_;

	unless( defined($kickmsg) && $kickmsg ne "" )
	{
		$kickmsg = $self->config()->param('default_kick_message');

		if( $kickmsg && -e $kickmsg )
		{
			if( open( my $fh, '<', $kickmsg ) )
			{
				my @lines = <$fh>;
				chomp(@lines);
				$kickmsg = @lines[rand @lines];
				close( $fh );
			}
			else
			{
				warn "Error opening '$kickmsg': $!";
			}
		}
	}

	$self->kernel()->post( 'pipsqueek', 'kick', 
		$channel, $target, $kickmsg );
}

# sets a mode on ourself or the channel specified
sub mode      { (shift)->kernel()->post( 'pipsqueek', 'mode',      @_ ); }
# change our nickname to a new nickname 
sub nick      { (shift)->kernel()->post( 'pipsqueek', 'nick',      @_ ); }
# notice a target with a message
sub notice    { (shift)->kernel()->post( 'pipsqueek', 'notice',    @_ ); }
# leave a channel
sub part      { (shift)->kernel()->post( 'pipsqueek', 'part',      @_ ); }

# sends a private message to the target destination
sub privmsg 
{ 
	my ($self,$target,$input) = @_;
	my $maxlen = 512 - 76 - length(": PRIVMSG $target :\r\n");
	# the 76 is to take into account the ident@host sent back to other
	# clients when a message is transmitted, ident is 11 chars, host is 64,
	# 1 for '@'.
	# if the message is too long for a single PRIVMSG, we'll send the output
	# as multiple PRIVMSGs, broken intelligently on spacing in the output

	unless( length($input) > $maxlen )
	{
		$self->kernel()->post('pipsqueek', 'privmsg', $target, $input);
		return;
	}

	# continue while we still have data to match
	while( my ($message) = $input =~ m/^(.{1,$maxlen})/ )
	{
		# is there more to send still after this match?
		if( length($message) != length($input) )
		{
			# break the message on spacing (only send everything up
			# to the last space available)
			$message =~ s/^(.*)\s+.*?$/$1/;
		}

		# strip the message we'll be sending from the remaining input
		$input =~ s/^\Q$message\E\s*//;

		# bon voyage, mon ami
		$self->kernel()->post('pipsqueek', 'privmsg', $target,$message);
	}
}

# disconnects the bot from the server
sub quit      { (shift)->kernel()->post( 'pipsqueek', 'quit',      @_ ); }
# sends the rawcode to the server on the bot's behalf
sub raw       { (shift)->kernel()->post( 'pipsqueek', 'sl',        @_ ); }

# reloads all the plugin modules for the bot
sub rehash    { (shift)->kernel()->yield( 'pipsqueek_load_modules' ); }

# convenience function to respond in appropriate context
# (when a plugin handles both the private and public of the same command)
sub respond
{
	my ($self,$message,@rest) = @_;

	if( $message->event() =~ /^private/ )  {
		$self->privmsg( $message->nick(),    @rest );
	} else {
		$self->privmsg( $message->channel(), @rest );
	}
}

# convenience function to respond with an action in appropriate context
sub respond_act
{
	my ($self,$message,@rest) = @_;

	if( $message->event() =~ /^private/ ) {
		$self->ctcp( $message->nick(),    "ACTION @rest" );
	} else {
		$self->ctcp( $message->channel(), "ACTION @rest" );
	}
	
}

# changes the topic in the channel
sub topic     { (shift)->kernel()->post( 'pipsqueek', 'topic',     @_ ); }

# whois a user
sub whois     { (shift)->kernel()->post( 'pipsqueek', 'whois',     @_ ); }




# Internal Functions

# Attempts to put english names to the arguments sent to standard PoCo::IRC 
# event handlers.  If you're writing a handler for pipsqueek for a specific 
# irc_bleh event, check what arguments are sent to it by printing out
# $self->parse(@_)->raw, then - if the arguments to that event would fit in 
# this parser (where it says 'custom mode parsing') please add the code and 
# email a diff file, otherwise just write the parsing yourself in your module 
sub parse
{
	my ($self,$event,@args) = (@_);

	my $message = PipSqueek::Message->new({
		'sender'     => undef,
		'nick'       => undef,
		'ident'      => undef,
		'host'       => undef,
		'recipients' => undef,
		'channel'    => undef,
		'message'    => undef,
		'raw'        => \@args,
		'event'      => $event,
	});

	if( $event eq 'irc_error' || $event eq 'irc_socketerr' )
	{
		$message->message($args[0]);
		return $message;
	}

	# save the sender info
	$message->sender($args[0]);

	# parse a nick!ident@hostmask sender into appropriate fields
	if( $args[0] =~ /^(.*?)!(.*?)\@(.*?)$/ )
	{
		$message->nick($1);
		$message->ident($2);
		$message->host($3);
	}

	my @recipients;
	# more than one argument sent?
	if( defined($args[1]) )
	{
		if( ref($args[1]) eq 'ARRAY' )
		{
			if( $args[1]->[0] =~ /^#/  )
			{
				$message->channel($args[1]->[0]);
			}

			foreach my $arg ( @{$args[1]} )
			{
				push( @recipients, $arg );
			}
		}
		else
		{
			# customized mode parsing

			# The above will catch most argument lists,
			# but there are quite a few (especially the irc_XXX
			# numeric events) that have arguments that require
			# special parsing
			
			if( $event eq 'irc_mode' )
			{
				if( $args[1] =~ /^#/ ) {
					$message->channel($args[1]);
				}
				else { $message->nick($args[1]); }
			}
			elsif( $event eq 'irc_353' ) 
			# list of names upon entering a channel
			{
				my ($channel,$names) = split(/:/, $args[1]);
				$channel =~ s/^.*#/#/g; $channel =~ s/ +$//g;

				$message->channel($channel);
				$message->recipients( [ split(/ /,$names) ] );
			}
			elsif( $event eq 'irc_kick' )
			{
				$message->channel($args[1]);
				push( @recipients, $args[2] );
				$message->message($args[3]);
			}
			else
			{
				$message->message($args[1]);
			}
		}
	}

	if( @recipients ) 
	{
		$message->recipients(@recipients);
	}

	# If we still have another argument, it's the event's message
	if( defined($args[2]) && !defined($message->message()) )
	{ 
		$message->message($args[2]);
	}

	return $message;
}


# attempts to locate the user sending $message (or nickname'd $message)
# in the user database.  In scalar context, returns just the user, in
# list context, returns the user and their userid
sub find_user
{
	my ($self,$message) = @_;
	my $nickname = ref($message) ? $message->nick() : $message;
	my $udb = $self->userdb();
	my $umi = $self->umapid();

#print STDERR "\n------------------------------\n";
#print STDERR "Trying to find user: $nickname\n";

	# We don't ever find ourselves
	return undef if lc($nickname) eq lc($self->nickname());

#print STDERR "\n",Dumper($umi),"\n",Dumper($udb),"\n\n";

	# Does the userid exist? Great, return the user
	if( my $uid = $umi->{lc($nickname)} )
	{
#print STDERR "Found user: $udb->{$uid}->{'username'} ($uid)\n";
		return wantarray ? ( $udb->{$uid}, $uid ) : $udb->{$uid};
	}

	# Does the user actually exist in the users database
	# (we're not mapping them but they exist, this situation can happen)
	foreach my $uid ( keys %$udb )
	{
		if( lc($nickname) eq lc($udb->{$uid}->{'username'}) 
		 || lc($nickname) eq lc($udb->{$uid}->{'nickname'})
		)
		{
#print STDERR "Found user: $udb->{$uid}->{'username'} ($uid)\n";
			# add an entry to the mapping table for this user
			$umi->{lc($nickname)} = $uid;

			# return the user
			return wantarray ? ($udb->{$uid}, $uid) : $udb->{$uid};
		}
	}

	
	if( ref($message) )
	{
		# If we got this far, create a new user and return that instead
		my @uids = reverse sort { $a <=> $b } keys %{$self->userdb()};
		my $uid = ($uids[0] || 0) + 10;
		my $lev = $self->config()->param('default_access_level') || 10;

#print STDERR "Created new user with id $uid\n";

		$udb->{$uid} = {
			'username' => $nickname,
			'nickname' => $nickname,
			'level' => $lev,
		};

		# Map the new username to their userid
		$umi->{lc($nickname)} = $uid;

		return wantarray ? ( $udb->{$uid}, $uid ) : $udb->{$uid};
	}
	else
	{
#print STDERR "Ended up being not found!";
		# user was not found (looked up by username, not by message)
		return undef;
	}
}


# loads the user database from disk and builds the id mapping
sub load_userdata
{
	my $self = shift;
	my $file = catfile( $self->cwd(), '/var/user.db' );

	if( -e $file )
	{
		# read file and save the hash away
		open( my $userfile, '<', $file ) 
			or die "Unable to read var/user.db: $!";
		my $userdb;
		eval( CORE::join('',<$userfile>) );
		$self->userdb($userdb ||= {});
		close( $userfile );

		my $umap = $self->umapid();

		# build the userid hash from usernames first
		foreach my $uid ( keys %$userdb ) {
			$umap->{lc($userdb->{$uid}->{'username'})} = $uid;
		}

		# then point nicknames at those userids too
		foreach my $uid ( keys %$userdb ) {
			$umap->{lc($userdb->{$uid}->{'nickname'})} = $uid;
		}
	}
	else
	{
		$self->userdb({});
	}
}


# writes the user database back to disk
sub save_userdata
{
	my $self = shift;
	my $file = catfile( $self->cwd(), '/var/user.db' );
	my $dumper = Data::Dumper->new( [$self->userdb()], [ 'userdb' ] );
	   #$dumper->Indent(0);

	open( my $fh, '>', $file ) or die "Unable to write var/user.db: $!";
	print $fh $dumper->Dump();
	close( $fh );
}


# Takes a hash and merges the argument list into it
# If the list is an array ref, it merges it as val1=>val1, val2=>val2, etc..
sub _merge {
        my ($self,$hash) = (shift,shift);
        if( scalar(@_) ) {
                my %data = ref($_[0]) eq 'HASH' ? %{$_[0]} :
                           ref($_[0]) eq 'ARRAY'? map{$_=>$_} @{$_[0]} : (@_);
                %{ $hash } = ( %{ $hash }, %data );
        }
        return $hash;
}


1; # module loaded successfully


