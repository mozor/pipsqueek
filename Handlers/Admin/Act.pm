package Handlers::Admin::Act;
#
# This package handles the admin 'act' command
# which makes the bot do a /me in the channel
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_act'	=> \&admin_act,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Does a /me in the channel" if( /admin_act/ );
	}
}


sub admin_act
{
	my $bot = shift;
	my $event = shift;

	$bot->ctcp( $bot->param('channel'), 'ACTION ' . $event->param('msg') );
}


1;


