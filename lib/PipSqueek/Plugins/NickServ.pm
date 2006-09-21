package PipSqueek::Plugins::NickServ;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'irc_001',
	]);
}

sub plugin_teardown { }

sub irc_001
{
	my ($self,$message) = @_;
	my $config = $self->config();

	if( $config->param('identify_with_nickserv') )
	{
		my $pass = $config->param('nickserv_password');
		$self->privmsg( "NickServ", "IDENTIFY $pass" );
	}
}


1;


