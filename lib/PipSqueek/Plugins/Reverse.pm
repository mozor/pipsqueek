package PipSqueek::Plugins::Reverse;
use base qw(PipSqueek::Plugin);

my @messages;

sub plugin_initialize {

	my $self = shift;

	$self->plugin_handlers([
		'multi_reverse',
		'irc_public',
	]);
}


sub irc_public {

	my ($self,$message) = @_;
	if (!$self->is_command($message)) {
		$messages[1] = $messages[0];
		$messages[0] = $message->message();
	}
}


sub plugin_teardown { }


sub multi_reverse {

	my ($self,$message) = @_;
	my ($text) = $message->message() =~ m/reverse\s+(.+)/;

	if ($text) {
		$text = reverse($text);
		return $self->respond($message, $message->nick() . ": $text");
	} else {
		if (length($messages[0]) > 3) {
			$text = reverse($messages[0]);
		} elsif (length($messages[1]) > 3) {
			$text = reverse($messages[1]);
		} else {
			$text = "Add some parameters or be quicker.";
		}

		return $self->respond($message, $message->nick() . ": $text");
	}
}

1;
