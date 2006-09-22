package PipSqueek::Plugin::Babelise;
use base qw(PipSqueek::Plugin);

use URI::URL;
use LWP::UserAgent;

sub plugin_initialize
{
    my $self = shift;
    $self->plugin_handlers({
        'multi_babelise' => 'babelise',
        'multi_babelize' => 'babelise',
    });
}


sub babelise
{
    my ($self,$message) = @_;
    
    my $url = 'http://www.tashian.com/perl/multibabel.cgi';
    my $text = $message->command_input();

    my $browser  = LWP::UserAgent->new( 'agent' => 'Mozilla/5.0' );
    my $response = $browser->post( 
            URI::URL->new($url)->as_string(),
            { 'english_text' => $text }
            );

    unless( $response->is_success() &&
        $response->content_type() eq 'text/html' )
    {
        $self->respond( $message, "HTTP Error or Invalid Content" );
        return;
    }

    my $results = $response->content();

    my ($output) = $results =~ m/<textarea.*?>(.*?)<\/textarea>/s;

    if( defined($output) && $output ne "" )
    {
        $self->respond( $message, $output );
    }
    else
    {
        $self->respond( $message, "Failed to translate" );
    }

    return;
}


1;


__END__
