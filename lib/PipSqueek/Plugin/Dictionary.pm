package PipSqueek::Plugin::Dictionary;
use base qw(PipSqueek::Plugin);

use URI::URL;


sub config_initialize
{
	my $self = shift;

	$self->plugin_configuration({
		'dictionary' => 1,
	});
}


sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers({
		'multi_dict'       => 'dictionary',
		'multi_dictionary' => 'dictionary',
	});

	if( $self->config()->dictionary() )
	{
		$self->plugin_handlers({
		'irc_public'       => 'dictionary',
		'irc_msg'          => 'dictionary',
		'irc_ctcp_action'  => 'dictionary',
		});
	}
}


sub dictionary
{
	my ($self,$message) = @_;

	my $cmd = $message->command();
	my $url = 'http://dictionary.reference.com/search?q=$word';

	if( $message->event() !~ /^irc_/ )
	{
		my $word = $message->command_input();
		   $word =~ s/\d+//g;
		    $url =~ s/\$word/$word/;
	}
	else
	{
		my $text = $message->message();
		if( $text =~ m/\b([\w-]{4,})\s*\(sp\??\)/ )
		{
			my $word = $1;
			$url =~ s/\$word/$word/;
		}
		else
		{
			return 0;
		}
	}

	return $self->respond( $message, URI::URL->new($url)->as_string() );
}


1;


__END__
