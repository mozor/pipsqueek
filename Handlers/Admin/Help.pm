package Handlers::Admin::Help;
#
# This package handles retrieving help for admin commands
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_help' => \&admin_help,
		'admin_list' => \&admin_help,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Returns the help for a command, or the list of commands available" if( /admin_help/ );
	}
}


sub admin_help
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');
	my $requested = $event->param('message')->[0];
	my $handlers = $bot->handler_registry();

	if( $requested )
	{
		my $type = $requested;
		$type =~ s/^!//;
		$type = 'admin_'.$type;

		unless( exists $handlers->{$type} ) {
			return $bot->privmsg( $nick, "That command does not exist" );
		}

		my $usage = $handlers->{$type}->{'obj'}->get_usage($type);
		my $desc = $handlers->{$type}->{'obj'}->get_description($type);

		$bot->privmsg( $nick, qq(Help on admin command '$requested') );
		$bot->privmsg( $nick, qq(Usage: $usage) );
		$bot->privmsg( $nick, qq(Description: $desc) );
	}
	else
	{
		my $list;
		
		foreach my $key (keys %$handlers)
		{
			if( $key =~ /^admin_/ )
			{
				$key =~ s/^admin_//;
				$list .= "${key}, ";
			}
		}
		chop($list); chop($list);

		$bot->privmsg( $nick, qq(Admin commands I understand are: $list) );
		if( $event->param('type') ne 'admin_list' )
		{
			my $botname = $bot->param('nickname');
			$bot->privmsg( $nick, qq(To get specific help on a command, try /msg $botname <password> help [<command name>]) );
		}
	}
}


1;

