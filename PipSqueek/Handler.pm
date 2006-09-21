package PipSqueek::Handler;

use strict;
use warnings;

# General Application Routines:
sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	
	my $self = {};
	$self->{'runpath'} = shift;

	bless($self,$class);

	$self->setup();

	return $self;
}


# custom handlers should always override these
sub get_handlers { die "Invalid handler"; }	# return a hash ref of event names and the
											# subroutine references that handle them
sub get_description { return "No description."; }	# describe what the handler does


# custom handlers can override these if their functionality is needed/wanted
sub setup { }		# called when the module is first created
sub teardown { }	# called when the module is about to be unloaded
sub get_usage { 	# show how to use the module (only for admin/public commands usually)
	return "Not available"; 
}

1; # module loaded successfully

