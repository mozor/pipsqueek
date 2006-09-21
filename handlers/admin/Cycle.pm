package Handlers::Admin::Cycle;
#
# admin_cycle makes the bot leave and rejoin a channel - is it useful? probably not
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_cycle'	=> \&admin_cycle,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "The bot will part and then rejoin a channel" if( /admin_cycle/ );
		}
}


sub admin_cycle
{
	my $bot = shift;
	$bot->part();
	$bot->join();
}


1;

