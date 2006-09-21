package PipSqueek::Plugin::AutoRejoin;
use base qw(PipSqueek::Plugin);


sub config_initialize
{
	my $self = shift;

	$self->plugin_configuration({
		'autorejoin' => '1',
	});
}


sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([ 
		'irc_kick',
	]);
}


sub irc_kick
{
	my ($self,$message) = @_;
	my $c = $self->config();

	my $autorejoin = $c->autorejoin();

	if( $message->recipients() eq $c->current_nickname() && $autorejoin )
	{
		$self->client()->join( $message->channel() );
	}
}


1;


__END__
