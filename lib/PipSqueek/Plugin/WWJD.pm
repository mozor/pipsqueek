package PipSqueek::Plugin::WWJD;
use base qw(PipSqueek::Plugin);
use strict;

#use Data::Dumper;


sub plugin_initialize 
{
    my $self = shift;
    my $c = $self->config();
    
    $self->plugin_handlers([
        'multi_wwjd'
    ]);
}


sub multi_wwjd
{
    my ($self,$message) = @_;
	
	my @CHAMBERS = ( "I'd do something", "Blame it on Chris", "Fuck the fucking fuckers!", "Forge an email from Darrin blaming it on them", "Go on vacation", "Eat a snickers bar"	);
	
	my $returnme = @CHAMBERS[rand @CHAMBERS];
	
	return $self->respond( $message, $returnme );

}


1;


__END__
