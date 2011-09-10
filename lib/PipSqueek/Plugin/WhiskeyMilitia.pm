package PipSqueek::Plugin::WhiskeyMilitia;
use base qw(PipSqueek::Plugin);
require LWP::UserAgent;


 sub plugin_initialize
 {
   my $self = shift;
   $self->plugin_handlers({
                  'multi_whiskey'      => 'whiskey_checker',
                  'multi_wm'      => 'whiskey_checker',

});

 }
sub whiskey_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
                my $uaw = LWP::UserAgent->new;
                        $uaw->timeout(15);

                my $cl = $uaw->get('http://www.WhiskeyMilitia.com/');
                my $content = $cl->content;


                my ($name) = $content =~ /item_title\">(.+?)<\/h1>/gis;
		my ($price) = $content =~ /<div id=\"price\">(.+?)</gis;
        return $self->respond( $message, "$name - $price - http://www.whiskeymilitia.com\n");


}


1;

 
