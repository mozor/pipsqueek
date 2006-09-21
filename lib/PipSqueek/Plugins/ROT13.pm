package PipSqueek::Plugins::ROT13;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_rot13',
	]);
}

sub plugin_teardown { }

sub multi_rot13
{
	my ($self,$message) = @_;
	my ($text) = $message->message() =~ m/rot13\s+(.+)/;

	if( $text )
	{
		$text =~ tr/A-Za-z/N-ZA-Mn-za-m/;
		return $self->respond( $message, $message->nick() . ": $text" );
	}
	else
	{
		return $self->respond( $message, "..." );
	}
}


1;


