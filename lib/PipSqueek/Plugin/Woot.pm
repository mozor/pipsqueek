package PipSqueek::Plugin::Woot;
use base qw(PipSqueek::Plugin);
require LWP::UserAgent;


 sub plugin_initialize
 {
   my $self = shift;
   $self->plugin_handlers({
                  'multi_woot'      => 'woot_checker'
});

 }
sub woot_checker {
   my ($self,$message) = @_;
   my $uaw = LWP::UserAgent->new;
	$uaw->timeout(15);
   
   my $woot = $uaw->get('http://www.woot-tracker.com/pips/index.php');
	
	if ($woot->is_success) {
		return $self->respond( $message,($woot->content) );
	
	} else {
        		return $self->respond( $message,("An error has occurred.") );
        }
}

1;

__END__
