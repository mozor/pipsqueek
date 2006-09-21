package PipSqueek::Plugins::Users;
use base qw(PipSqueek::Plugin);
use strict;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		# connection events
		'irc_001',

		# nickname tracking
		'irc_nick',
		'irc_quit',
		'irc_part',

		# pipsqueek features
		'private_register',
		'private_identify',
		'private_cloaking',
	]);
}

sub plugin_teardown { }

sub irc_001
{
	my ($self,$message) = @_;
	my $userdb = $self->userdb();

	foreach ( keys %$userdb )
	{
		$userdb->{$_}->{'identified'} = 0;
	}
}

sub irc_nick
{
	my ($self,$message) = @_;
	my ($user,$uid) = $self->find_user($message);
	my ($nuser,$nuid) = $self->find_user( $message->message() );

	my $nick_from = $message->nick();
	my $nick_to   = $message->message();

	# change nicks in the mapping table
	my $umapid = $self->umapid();
	$umapid->{lc($nick_from)} = $uid;
	$umapid->{lc($nick_to)} = $nuid || $uid;
}

sub irc_part
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);
	$user->{'identified'} = 0;
}

sub irc_quit
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);
	$user->{'identified'} = 0;
}

sub private_register
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);

	if( $user->{'registered'} )
	{
		return $self->respond( $message,
			"This account is registered already" );
	}

	my ($password,$username) = 
		$message->message() =~ m/register\s+(.+?)\s+(.+?)$/;

	unless( defined $password && defined $username )
	{
		return $self->respond( $message,
			"Please use !help register, for help on registering" );
	}

	$user->{'password'} = $password;
	$user->{'username'} = $username;

	$user->{'registered'} = 1;
	$user->{'identified'} = 1;

	return $self->respond( $message, "Ahoy! You are now registered" );
}

sub private_identify
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);

	if( !$user->{'registered'} )
	{
		return $self->respond( $message, 
			"This account is not yet registered. " .
			"Please use !help register for more info" );
	}
	
	my ($password) = $message->message() =~ m/identify\s+(.+?)$/;

	if( defined($password) && $user->{'password'} eq $password )
	{
		$user->{'identified'} = 1;
		return $self->respond( $message, "You are now identified" );
	}
	else
	{
		return $self->respond( $message, "Identification failed" );
	}
}

sub private_cloaking
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);

	if( !$user->{'registered'} )
	{
		return $self->respond( $message, 
			"Registration required for this feature. " .
			"Please use !help register for more info" );
	}

	$user->{'cloaking'} = $user->{'cloaking'} ? 0 : 1;

	if( $user->{'cloaking'} )
	{
		return $self->respond( $message, "Cloaking is now enabled" );
	}
	else
	{
		return $self->respond( $message, "Cloaking is now disabled" );
	}
}


1;


