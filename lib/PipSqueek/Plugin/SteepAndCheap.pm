package PipSqueek::Plugin::SteepAndCheap;
use base qw(PipSqueek::Plugin);
require LWP::UserAgent;


 sub plugin_initialize
 {
   my $self = shift;
   $self->plugin_handlers({
                  'multi_steep'      => 'steep_checker',
                  'multi_sc'      => 'steep_checker',

});

 }
sub steep_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
                my $uaw = LWP::UserAgent->new;
                        $uaw->timeout(15);

                my $cl = $uaw->get('http://www.steepandcheap.com/');
                my $content = $cl->content;


                #my ($name) = $content =~ /item_title\">(.+?)<\/h1>/gis;
                #my ($price) = $content =~ /<div id=\"price\">(.+?)</gis;
				
				my ($line) = $content =~ /<title>Steep and Cheap: (.+?)</gis;
        return $self->respond( $message, "$line - http://www.steepandcheap.com\n");


}


1;


