package PipSqueek::Plugins::Admin;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_rehash',
		'multi_topic',
		'multi_shutdown',
		'multi_say',
		'multi_act',
		'multi_raw',
		'multi_part',
		'multi_join',
		'multi_cycle',
		'multi_save',
		'multi_load',
		'multi_setlevel',

		'multi_kick',
		'multi_ban',
		'multi_kickban',
	]);
}

sub plugin_teardown { }


sub multi_save
{
	my ($self,$message) = @_;
	$self->kernel()->yield( 'pipsqueek_save_userdata' );

	return $self->respond( $message, "Ok" );
}

sub multi_load
{
	my ($self,$message) = @_;
	$self->kernel()->yield( 'pipsqueek_load_userdata' );

	return $self->respond( $message, "Ok" );
}

sub multi_rehash
{
	my ($self,$message) = @_;

	$self->rehash();

	return $self->respond( $message, "Bot rehashed" );
}

sub multi_topic
{
	my ($self,$message) = @_;
	my ($channel,$topic) = $message->message() =~ m/topic\s+(?:(#.*?)\s+?)?(.+?)$/;
	$channel ||= $self->config()->param('server_channel');

	$self->topic( $channel, $topic );
}

sub multi_shutdown
{
	my ($self,$message) = @_;
	$self->kernel()->yield( 'pipsqueek_shutdown' );
}

sub multi_say
{
	my ($self,$message) = @_;
	my ($text) = $message->message() =~ m/say\s+(.*?)$/;

	$self->chanmsg( $text );
}

sub multi_act
{
	my ($self,$message) = @_;
	my ($text) = $message->message() =~ m/act\s+(.*?)$/;

	$self->ctcp( $self->config()->param('server_channel'), "ACTION $text" );
}

sub multi_raw
{
	my ($self,$message) = @_;
	my ($raw) = $message->message() =~ m/raw\s+(.*?)$/;

	$self->raw( $raw );
}

sub multi_part
{
	my ($self,$message) = @_;
	my ($channel) = $message->message() =~ m/part\s+(.*?)$/;
	$channel ||= $self->config()->param('server_channel');

	$self->part( $channel );
}

sub multi_join
{
	my ($self,$message) = @_;
	my ($channel) = $message->message() =~ m/join\s+(.*?)$/;
	$channel ||= $self->config()->param('server_channel');

	$self->join( $channel );
}

sub multi_cycle
{
	my ($self,$message) = @_;
	my ($channel) = $message->message() =~ m/cycle\s+(.*?)$/;
	$channel ||= $self->config()->param('server_channel');

	$self->part( $channel );
	$self->join( $channel );
}

sub multi_setlevel
{
	my ($self,$message) = @_;
	my ($name,$level) = $message->message() =~ m/setlevel\s+(.+?)\s+(\d+?)$/;

	if( $name && defined($level) )
	{
		if( my $user = $self->find_user($name) )
		{
			$user->{'level'} = $level;
		}
		else
		{
			return $self->respond( $message, "That user does not exist" );
		}
	}
}

sub multi_kick
{
	my ($self,$message,$username,@args) = @_;

	my $channel;
	if( $args[0] =~ /^#/ ) {
		$channel = shift @args;
	}

	$channel ||= $message->channel() || 
		$self->config()->param('server_channel');

	my $kickmsg = join(' ',@args);

	return unless $username;

	$self->kick( $channel, $username, $kickmsg );
}
		
sub multi_ban
{
	my ($self,$message,$username,$channel,$mode) = @_;

	if( !$mode && $channel =~ /^[1-7]$/ )
	{
		$mode = $channel;
		$channel = undef;
	}

	$channel ||= $message->channel() || $self->config()->param('server_channel');

	$self->ban( $channel, $username, $mode );
}

sub multi_kickban
{
	my ($self,$message,$username,@args) = @_;

	my $channel;
	my $banmode;

	if( $args[0] =~ /^#/ ) {
		$channel = shift @args;
	}
	if( $args[0] =~ /^[1-7]$/ ) {
		$banmode = shift @args;
	}

	$self->multi_ban( $message, $username, $channel, $banmode );
	$self->multi_kick( $message, $username, $channel, @args );
}

1;


