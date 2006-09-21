package PipSqueek::Plugins::AutoSpell;
use base qw(PipSqueek::Plugin);

use URI::URL;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers(
		'irc_public' => 'irc_public',
		'irc_ctcp_action' => 'irc_ctcp_action',
	);
}

sub plugin_teardown { }

sub make_url {
	my ($self,$text) = @_;
	
	if( $text =~ m/\b([\w-]{4,})\s*\(sp\??\)/ )
	{
		my $word = $1;
		my $url = "http://dictionary.reference.com/search?q=$word";
		return URI::URL->new($url);
	}

	return undef;
}


sub irc_public
{
	my ($self,$message) = @_;
	return if $self->is_command($message);

	if( my $url = $self->make_url( $message->message() ) )
	{
		return $self->respond( $message, $url->as_string() );
	}
}

sub irc_ctcp_action
{
	my ($self,$message) = @_;
	
	if( my $url = $self->make_url( $message->message() ) )
	{
		return $self->privmsg( $message->channel(), $url->as_string() );
	}
}


1;


