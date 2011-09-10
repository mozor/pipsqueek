package PipSqueek::Plugin::Tramdock;
use base qw(PipSqueek::Plugin);
require LWP::UserAgent;


 sub plugin_initialize
 {
   my $self = shift;
   $self->plugin_handlers({
                  'multi_tramdock'      => 'tram_checker',     
                  'multi_td'      => 'tram_checker',              
				  
});

 }
sub tram_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
		my $uaw = LWP::UserAgent->new;
			$uaw->timeout(15);

		my $cl = $uaw->get('http://www.tramdock.com/');
		my $content = $cl->content;


		my ($name) = $content =~ /item_title\">(.+?)<\/h1>/gis;
                my ($price) = $content =~ /<div id=\"price\">(.+?)</gis;

        return $self->respond( $message, "$name - $price - http://www.tramdock.com\n");


}


1;
