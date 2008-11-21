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

});

 }
sub woot_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
   my $woot = $uaw->get('http://www.woot-tracker.net/pips/index.php');

        if ($woot->is_success) {
                return $self->respond( $message,($woot->content) );

        } else {
                        return $self->respond( $message,("An error has occurred.") );
        }
}

sub wine_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
   my $woot = $uaw->get('http://www.woot-tracker.net/pips/wine.php');

        if ($woot->is_success) {
                return $self->respond( $message,($woot->content) );

        } else {
                        return $self->respond( $message,("An error has occurred.") );
        }
}

sub shirt_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
        $uaw->timeout(15);

   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
   my $woot = $uaw->get('http://www.woot-tracker.net/pips/shirt.php');

        if ($woot->is_success) {
                return $self->respond( $message,($woot->content) );

        } else {
                        return $self->respond( $message,("An error has occurred.") );
        }
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


1;

__END__
