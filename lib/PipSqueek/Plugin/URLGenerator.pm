package PipSqueek::Plugin::URLGenerator;
use base qw(PipSqueek::Plugin);

use URI::URL;

sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers(
                'multi_sw'          => 'generate_url',
                'multi_physics'     => 'generate_url',
                'multi_mw'          => 'generate_url',
                'multi_mathworld'   => 'generate_url',
                'multi_imdb'        => 'generate_url',
                'multi_wiki'        => 'generate_url',
        'multi_cpan'        => 'generate_url',
        'multi_perldoc'     => 'generate_url',
        'multi_fm'          => 'generate_url',
        'multi_freshmeat'   => 'generate_url',
        'multi_sourceforge' => 'generate_url',
        'multi_sf'          => 'generate_url',
        'multi_google'      => 'generate_url',
        'multi_gimg'        => 'generate_url',
        'multi_search'      => 'generate_url',
        'multi_mbartist'    => 'generate_url',
        'multi_mbalbum'     => 'generate_url',
        'multi_mbtrack'     => 'generate_url',
    );
}


sub generate_url
{
    my ($self,$message) = @_;

    my %urls = (
    'cpan'        =>
    [ 'http://search.cpan.org', '/search?mode=module&query=$search' ],

    'google'    => 
    [ 'http://lmgtfy.com', '/?q=$search' ],

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
