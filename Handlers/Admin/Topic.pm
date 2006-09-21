package Handlers::Admin::Topic;
#
# Let's a bot admin change the topic in the channel with the bot
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_topic'	=> \&admin_topic,
	};
}


sub get_description 
{ 
	return "Change the topic in the channel";
}

sub get_usage
{
	return "topic <new topic>";
}

sub admin_topic
{
	my $bot = shift;
	my $event = shift;

	$bot->topic($event->param('msg'));
}


1;

