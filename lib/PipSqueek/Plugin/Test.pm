package PipSqueek::Plugin::Test;
use base qw(PipSqueek::Plugin);
use strict;

use Data::Dumper;


sub plugin_initialize 
{
	my $self = shift;
	my $c = $self->config();
	
	$self->plugin_handlers([
		'multi_test'
	]);
}


sub multi_test
{
	my ($self,$message) = @_;
	
	print Dumper($self->client()->get_heap()->{'LEVELS'});

	return $self->respond( $message, "Testing, 1 2 3..." );
}


1;


__END__
