package PipSqueek::Plugin::Chainlove;
use base qw(PipSqueek::Plugin);
require LWP::UserAgent;


 sub plugin_initialize
 {
   my $self = shift;
   $self->plugin_handlers({
                  'multi_chain'      => 'chain_checker',     
                  'multi_cl'      => 'chain_checker',              
				  
});

 }
sub chain_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
		my $uaw = LWP::UserAgent->new;
			$uaw->timeout(15);

		my $cl = $uaw->get('http://www.chainlove.com/');
		my $content = $cl->content;


		my ($name) = $content =~ /item_title\">(.+?)<\/h1>/gis;
                my ($price) = $content =~ /<div id=\"price\">(.+?)</gis;

        return $self->respond( $message, "$name - $price - http://www.chainlove.com\n");


}


1;

