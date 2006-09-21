package PipSqueek::Plugins::URLGen;
use base qw(PipSqueek::Plugin);

use URI::URL;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers(
		'multi_cpan'        => 'generate_url',
		'multi_google'      => 'generate_url',
		'multi_perldoc'     => 'generate_url',
		'multi_freshmeat'   => 'generate_url',
		'multi_sourceforge' => 'generate_url',
		'multi_dictionary'  => 'generate_url',
		'multi_search'      => 'generate_url',
		'multi_dict'        => 'generate_url',
	);
}

sub plugin_teardown { }

sub generate_url
{
	my ($self,$message) = @_;
	
	my %urls = (
'cpan'        => 'http://search.cpan.org/search?mode=module&query=::search::',
'google'      => 'http://www.google.com/search?q=::search::',
'search'      => 'http://www.google.com/search?q=::search::',
'perldoc'     => 'http://www.perldoc.com/cgi-bin/htsearch?words=::search::',
'freshmeat'   => 'http://freshmeat.net/search/?q=::search::&section=projects',
'sourceforge' => 'http://sf.net/search/?type_of_search=soft&words=::search::',
'dictionary'  => 'http://dictionary.reference.com/search?q=::search::',
'dict'        => 'http://dictionary.reference.com/search?q=::search::',
	);

	my $event = $message->event();
	$event =~ s/^(?:private|public)_//;

	my $url = $urls{$event};
	my ($search) = $message->message() =~ m/$event\s+(?:for\s+)?(.*?)$/;
	$url =~ s/::search::/$search/;
	$url = URI::URL->new($url);

	return $self->respond( $message, $url->as_string() );
}


1;


