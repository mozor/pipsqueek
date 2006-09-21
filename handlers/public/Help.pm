package Handlers::Public::Help;
#
# This package handles retrieving help for public commands
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_help' => \&public_help,
		'public_list' => \&public_help,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Returns the help for a command, or the list of commands available" if( /public_help/ );
	}
}


sub public_help
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
		$type = 'public_'.$type;

		unless( exists $handlers->{$type} ) {
			return $bot->notice( $nick, "That command does not exist" );
		}

		my $usage = $handlers->{$type}->{'obj'}->get_usage($type);
		my $desc = $handlers->{$type}->{'obj'}->get_description($type);

		$bot->notice( $nick, qq(Help on public command '$requested') );
		$bot->notice( $nick, qq(Usage: $usage) );
		$bot->notice( $nick, qq(Description: $desc) );
	}
	else
	{
		my $list;
		my $cmdprefix = $bot->param('command_prefix');
		
		foreach my $key (keys %$handlers)
		{
			if( $key =~ /^public_/ )
			{
				$key =~ s/^public_//;
				$list .= "${cmdprefix}${key}, ";
			}
		}
		chop($list); chop($list);

		$bot->notice( $nick, qq(Public commands I understand are: $list) );
		if( $event->param('type') ne 'public_list' )
		{
			$bot->notice( $nick, qq(To get specific help on a command, try !help <command name>) );
		}
	}
}


1;

