package Handlers::Admin::Raw;
#
# This package handles the admin event 'raw', which just sends
# raw commands to the server on behalf of the bot
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_raw'	=> \&admin_raw,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Send a raw server command on behalf of the bot" if( /admin_raw/ );
		}
}


sub admin_raw
{
	my $bot = shift;
	my $event = shift;

	$bot->raw( $event->param('msg') );
}


1;


