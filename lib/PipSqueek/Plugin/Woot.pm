package PipSqueek::Plugin::Woot;
use base qw(PipSqueek::Plugin);
require LWP::UserAgent;


 sub plugin_initialize
 {
   my $self = shift;
   $self->plugin_handlers({
                  'multi_woot'      => 'woot_checker',
                  'multi_shirt'      => 'shirt_checker',
                  'multi_wine'      => 'wine_checker',
                  'multi_sellout'      => 'sellout_checker',
                  'multi_kids'      => 'kids_checker',



});

 }
sub woot_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
        my $woot = $uaw->get('http://www.woot.com/');
        my $content = $woot->content;


        my ($name) = $content =~ /<h2 class=\"fn\">(.+?)<\/h2/gis;
        my ($price) = $content =~ /<span class=\"amount\">(.+?)</gis;
        my ($url) = $content =~ /\/WantOne.aspx(.+?)\"/gis;


        return $self->respond( $message, "$name - \$$price +\$5 Shipping - http://www.woot.com/WantOne.aspx$url\n");
}


sub wine_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
        my $woot = $uaw->get('http://wine.woot.com/');
        my $content = $woot->content;


        my ($name) = $content =~ /<h2 class=\"fn\">(.+?)<\/h2/gis;
        my ($price) = $content =~ /<span class=\"amount\">(.+?)</gis;
        my ($url) = $content =~ /\/WantOne.aspx(.+?)\"/gis;


        return $self->respond( $message, "$name - \$$price +\$5 Shipping - http://wine.woot.com/WantOne.aspx$url\n");



}

sub shirt_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
        my $woot = $uaw->get('http://shirt.woot.com/');
        my $content = $woot->content;


        my ($name) = $content =~ /<h2 class=\"fn\">(.+?)<\/h2/gis;
        my ($price) = $content =~ /<span class=\"amount\">(.+?)</gis;
        my ($url) = $content =~ /\/WantOne.aspx(.+?)\"/gis;


        return $self->respond( $message, "$name - \$$price +\$5 Shipping - http://shirt.woot.com/WantOne.aspx$url\n");


}

sub sellout_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
        my $woot = $uaw->get('http://shopping.yahoo.com/?name=woot');
        my $content = $woot->content;


        my ($name) = $content =~ /rel=\"nofollow\" >(.+?)<\/a><\/h2/gis;
        my ($price) = $content =~ /<p class=\"price\"><strong>(.+?)</gis;
        my ($url) = $content =~ /sellout.woot.com\/(.+?)\" alt/gis;


        return $self->respond( $message, "$name - $price - http://sellout.woot.com/$url\n");


}

sub kids_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
        my $woot = $uaw->get('http://kids.woot.com/');
        my $content = $woot->content;


        my ($name) = $content =~ /<h2 class=\"fn\">(.+?)<\/h2/gis;
        my ($price) = $content =~ /<span class=\"amount\">(.+?)</gis;
        my ($url) = $content =~ /\/WantOne.aspx(.+?)\"/gis;


        return $self->respond( $message, "$name - \$$price +\$5 Shipping - http://kids.woot.com/WantOne.aspx$url\n");


}




1;

__END__

