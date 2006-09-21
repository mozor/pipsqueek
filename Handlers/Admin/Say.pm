package Handlers::Admin::Say;
#
# This package handles the admin_say event, which makes the bot
# say something in the channel.
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_say'	=> \&admin_say,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "The bot says whatever you tell it to in the channel" if( /admin_say/ );
		}
}


sub admin_say
{
	my $bot = shift;
	my $event = shift;
	$bot->chanmsg( $event->param('msg') );
}

1;


