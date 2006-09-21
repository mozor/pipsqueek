package PipSqueek::Plugin::CapsLockCop;
use base qw(PipSqueek::Plugin);


sub config_initialize
{
	my $self = shift;

	$self->plugin_configuration({
		'capslockcop' => 1,
		'capslockcop_percentage_caps' => 75,
		'capslockcop_minimum_length' => 12,
		'capslockcop_kick_message' => 'TURN OFF YOUR CAPSLOCK',
	});
}


sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'irc_public',
	]);
}


sub irc_public
{
	my ($self,$message) = @_;
	my $c = $self->config();

	return if $message->is_command();
	return unless $c->capslockcop();

	my $text = $message->message() || return;

	my $cl_per = $c->capslockcop_percentage_caps();
	my $cl_min = $c->capslockcop_minimum_length();
	my $cl_msg = $c->capslockcop_kick_message();

	my $msg_cap = $text =~ tr/A-Z/A-Z/;
	my $msg_len = length($text);
	my $msg_per = ($msg_cap/$msg_len)*100;

	if( $msg_len > $cl_min && $msg_per >= $cl_per )
	{
		$self->client()->kick( $message->channel(),
					$message->nick(), 
					$cl_msg );
		return 1;
	}

	return 0;
}


1;


__END__
