package PipSqueek::Plugin::URLGenerator;
use base qw(PipSqueek::Plugin);

use URI::URL;

sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers(
        map { 'multi_' . $_ => 'generate_url' } qw{
            sw physics mw mathworld imdb wiki cpan perldoc fm freshmeat
            sourceforge sf google gimg search mbartist mbalbum mbtrack
            lmgtfy bing map amazon zillow
        }
    );
}


sub generate_url
{
    my ($self,$message) = @_;

    my %urls = (
    'cpan'        =>
    [ 'http://search.cpan.org', '/search?mode=module&query=$search' ],

    'google'    => 
    [ 'http://www.google.com', '/search?q=$search' ],

    'search'    =>
    [ 'http://www.google.com', '/search?q=$search' ],

    'gimg'      =>
    [ 'http://images.google.com', '/images?q=$search' ],

    'perldoc'    =>
    [ 'http://www.perldoc.com', '/cgi-bin/htsearch?words=$search' ],
        
    'freshmeat'    =>
    [ 'http://freshmeat.net', '/search/?q=$search&section=projects' ],

    'fm'    =>
    [ 'http://freshmeat.net', '/search/?q=$search&section=projects' ],

    'sourceforge'    => 
    [ 'http://sf.net', '/search/?type_of_search=soft&words=$search' ],

    'sf'        =>
    [ 'http://sf.net', '/search/?type_of_search=soft&words=$search' ],

    'wiki'        =>
    [ 'http://en.wikipedia.org',
      '/wiki/Special:Search?go=Go&search=$search' ],

    'imdb'        =>
    [ 'http://imdb.com', '/Find?$search' ],

    'mathworld'    =>
    [ 'http://mathworld.wolfram.com', '/search/index.cgi?q=$search' ],

    'mw'        =>
        [ 'http://mathworld.wolfram.com', '/search/index.cgi?q=$search' ],

    'physics'    =>
    [ 'http://scienceworld.wolfram.com',
      '/search/index.cgi?sitesearch=scienceworld.wolfram.com%2Fphysics&q=$search' ],

    'sw'        =>
        [ 'http://scienceworld.wolfram.com',
      '/search/index.cgi?sitesearch=scienceworld.wolfram.com%2Fphysics&q=$search' ],

    'mbalbum'    =>
    [ 'http://musicbrainz.org',
      '/newsearch.html?limit=25&table=album&search=$search' ],

    'mbartist'    =>
    [ 'http://musicbrainz.org',
      '/newsearch.html?limit=25&table=artist&search=$search' ],

    'mbtrack'    =>
    [ 'http://musicbrainz.org',
      '/newsearch.html?limit=25&table=track&search=$search' ],

    'lmgtfy'	=>
    [ 'http://lmgtfy.com',
      '/?q=$search' ],

    'bing' => 
    [ 'http://www.bing.com',
       '/search?q=$search' ],

    'amazon' => 
    [ 'http://www.amazon.com',
       '/s/?url=search-alias%3Daps&field-keywords=$search' ],

    'zillow' => 
    [ 'http://www.zillow.com',
      '/homes/$search' ],

    'map' => 
    [ 'http://maps.google.com',
      '/maps?q=$search' ],

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
