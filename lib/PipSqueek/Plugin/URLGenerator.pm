package PipSqueek::Plugin::URLGenerator;
use base qw(PipSqueek::Plugin);

use URI::URL;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers(
		'multi_cpan'        => 'generate_url',
		'multi_perldoc'     => 'generate_url',
		'multi_freshmeat'   => 'generate_url',
		'multi_sourceforge' => 'generate_url',
		'multi_sf'          => 'generate_url',
		'multi_google'      => 'generate_url',
		'multi_search'      => 'generate_url',
	);
}


sub generate_url
{
	my ($self,$message) = @_;

	my %urls = (
	'cpan'		=>
	[ 'http://search.cpan.org', '/search?mode=module&query=$search' ],

	'google'	=> 
	[ 'http://www.google.com', '/search?q=$search' ],

	'search'	=>
	[ 'http://www.google.com', '/search?q=$search' ],

	'perldoc'	=>
	[ 'http://www.perldoc.com', '/cgi-bin/htsearch?words=$search' ],
		
	'freshmeat'	=>
	[ 'http://freshmeat.net', '/search/?q=$search&section=projects' ],

	'sourceforge'	=> 
	[ 'http://sf.net', '/search/?type_of_search=soft&words=$search' ],

	'sf'		=>
	[ 'http://sf.net', '/search/?type_of_search=soft&words=$search' ],
	);


	my $event = $message->event();
	   $event =~ s/^(?:private|public)_//;

	my $text = $message->command_input();
	   $text =~ s/^for\s*//i; # !search for whatever

	my $parts = $urls{$event};
	my $url = $parts->[0];

	if( $text )
	{
		$url .= $parts->[1];
		$url =~ s/\$search/$text/;
	}

	$url = URI::URL->new($url);

	return $self->respond( $message, $url->as_string() );
}


1;


__END__
