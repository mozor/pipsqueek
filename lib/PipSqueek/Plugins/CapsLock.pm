package PipSqueek::Plugins::CapsLock;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'irc_public',
	]);
}

sub plugin_teardown { }

sub irc_public
{
	my ($self,$message) = @_;

	return if $self->is_command($message);
	return unless $self->config()->param('capslock_kick');

	my $text = $message->message() || return;

	my $cl_per = $self->config()->param('capslock_percentage_caps') || 75;
	my $cl_min = $self->config()->param('capslock_minimum_length') || 12;
	my $cl_msg = $self->config()->param('capslock_kick_message');

	my $msg_cap = $text =~ tr/A-Z/A-Z/;
	my $msg_len = length($text);
	my $msg_per = ($msg_cap/$msg_len)*100;

	if( $msg_len > $cl_min && $msg_per >= $cl_per )
	{
		$self->kick( $message->channel(), $message->nick(), $cl_msg );
	}
}


1;


