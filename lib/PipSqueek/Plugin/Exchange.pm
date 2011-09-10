package PipSqueek::Plugin::Exchange;
use base qw(PipSqueek::Plugin);
use strict;

#use Data::Dumper;


sub plugin_initialize 
{
    my $self = shift;
    my $c = $self->config();
    
    $self->plugin_handlers([
        'multi_email'
    ]);
}


sub multi_email
{
    my ($self,$message) = @_;
	
	my @CHAMBERS = ( "Email is up","Email is down","Email kinda works","Email works but with a 2 day waiting period" );
    my $returnme = @CHAMBERS[rand @CHAMBERS];

	return $self->respond( $message, $returnme );
}


1;


__END__
