package Handlers::Admin::Shutdown;
#
# This package handles admin_shutdown, for shutting down the bot (duh);
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_shutdown'	=> \&admin_shutdown,
	};
}


sub get_description 
{ 
	return "Shuts the bot down";
}

sub get_usage
{
	return "shutdown";
}

sub admin_shutdown
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;
	
	$bot->shutdown();
}


1;


