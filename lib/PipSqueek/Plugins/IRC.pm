package PipSqueek::Plugins::IRC;
use base qw(PipSqueek::Plugin);

use File::Spec::Functions;

my $LEVELS;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		# general event handlers
		'irc_msg',
		'irc_public',

		# connection handlers
		'irc_001',          # server welcome message
		'irc_error',        # server error
		'irc_433',          # nickname is in use

		# ctcp handlers
		'irc_ctcp_version',
		'irc_ctcp_ping',
	]);

	my $file = catfile( $self->cwd(), '/etc/levels.conf' );
	if( -e $file )
	{
		open( my $fh, '<', $file ) 
			or die "Unable to open file '$file': $!";
		my @lines = <$fh>;
		chomp(@lines);
		close( $fh );

		foreach my $line (grep(/=/,@lines))
		{
			my ($k,$v) = split(/=/,$line);
			$LEVELS->{$k} = $v;
		}
	}
}

sub plugin_teardown { }


sub irc_ctcp_version
{
	my ($self,$message) = @_;
	$self->ctcpreply( $message->nick(), $self->version() );
}

sub irc_ctcp_ping
{
	my ($self,$message) = @_;
	$self->ctcpreply( $message->nick(), 'PING ' . $message->message() );
}

sub irc_error
{
	my ($self,$message) = @_;
	print "Server error: ", $message->message(), "\n";
	$self->kernel()->yield( 'pipsqueek_connect' );
}

sub irc_001
{
	my ($self,$message) = @_;
	my $config = $self->config();

	# most networks require us to identify ourselves as a bot with mode +B
	$self->mode( $config->param('identity_nickname'), '+B' );

	$self->join( $config->param('server_channel') );
}

sub irc_433
{
	my ($self,$message) = @_;
	my $config = $self->config();

	my $alternate = $config->param('identity_nickname') . "_";
	$config->param('identity_nickname' => $alternate );

	$self->nick( $alternate );

	$self->join( $config->param('server_channel') );
}

sub irc_msg    { (shift)->_delegate_command(@_) }
sub irc_public { (shift)->_delegate_command(@_) }

sub _delegate_command
{
	my ($self,$message) = @_;
	return unless( $_ = $self->is_command($message) );

	my $command = $_;
	my $config  = $self->config();

	my $c_padmin = $config->param('primary_admin');
	my $c_access = $config->param('default_access_level') || 10;
	my $c_regist = $config->param('only_registered_users');
	my $c_identi = $config->param('require_identified_at') || 100;

	my $user  = $self->find_user($message);
	my $level = $LEVELS->{$command} || $c_access;

	# is this the primary admin ?
	if( $c_padmin && lc($c_padmin) eq lc($user->{'username'}) )
	{
		# do we need to increase their level?
		if( $user->{'level'} < 1000 )
		{
			$user->{'level'} = 1000;
		}
	}

	# unless they happen to be registering, do we require registration
	# for any commands ?
	if( $c_regist && !$user->{'registered'} && $command ne 'register' )
	{
		return $self->privmsg( $message->nick(), 
			"You must be registered to use any command. " .
			"Use !help register" );
	}

	# Are they authorized for this command?
	unless( $user->{'level'} >= $level )
	{
		return $self->privmsg( $message->nick(), 
			"You are not authorized to use this command" );
	}

	# unless they happen to be identifying, do we require them to be
	# identified for this command?
	if( $level > $c_identi && !$user->{'identified'} &&
		$command ne 'identify' )
	{
		return $self->privmsg( $message->nick(),
			"You must be identified to use that command" );
	}

	# And finally, let's send the event off to the kernel
	if( $message->event() eq 'irc_msg' )
	{
		$self->kernel()->yield("private_$command", @{$message->raw()});
	}
	elsif( $message->event() eq 'irc_public' )
	{
		$self->kernel()->yield("public_$command" , @{$message->raw()});
	}
}


1;


