package Handlers::Admin::Rehash;
#
# This package handles the admin event 'rehash', which tells
# the bot it needs to recompile all it's modules and stuff
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_rehash'	=> \&admin_rehash,
	};
}


sub get_description 
{ 
	return "Recompiles/loads the bots event handlers";
}

sub get_usage
{
	return "rehash";
}


sub admin_rehash
{
	my $bot = shift;
	my $event = shift;

	$bot->rehash();
}


1;


