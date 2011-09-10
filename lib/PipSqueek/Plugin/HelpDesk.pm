package PipSqueek::Plugin::HelpDesk;
use base qw(PipSqueek::Plugin);
use strict;

#use Data::Dumper;


sub plugin_initialize 
{
    my $self = shift;
    my $c = $self->config();
    
    $self->plugin_handlers([
        'multi_hd'
    ]);
}


sub multi_hd
{
    my ($self,$message) = @_;

	my @CHAMBERS = ( "Phone is ringing!", "WE NEED THE HELP DESK!", "Darrin?", "Phone!" );
	my $returnme = @CHAMBERS[rand @CHAMBERS];

	return $self->respond( $message, "Tristan: $returnme" );
}


1;


__END__
