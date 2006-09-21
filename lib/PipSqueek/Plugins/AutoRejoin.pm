package PipSqueek::Plugins::AutoRejoin;
use base qw(PipSqueek::Plugin);

use URI::URL;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'irc_kick',
	]);
}

sub plugin_teardown { }

sub irc_kick
{
	my ($self,$message) = @_;

	if( $self->config()->param('rejoin_on_kick') )
	{
		if( $message->recipients() eq $self->config()->param('identity_nickname') )
		{
			$self->join( $message->channel() );
		}
	}
}


1;


