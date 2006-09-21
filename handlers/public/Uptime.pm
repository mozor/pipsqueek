package Handlers::Public::Uptime;
#
# This handler reports how long the bot has been running
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_uptime'	=> \&public_uptime,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Reports how long the bot has been running" if( /public_uptime/ );
		}
}


sub public_uptime
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $uptime = $bot->uptime();

	my $days	= int($uptime / 86400);	$uptime = $uptime % 86400;
	my $years	= int(  $days / 365 );	$days   = $days   % 355;
	my $centur	= int( $years / 100 );	$years  = $years  % 100;
	my $millen	= int($centur / 10 );	$centur = $centur % 10;
	my $hours	= int($uptime / 3600);	$uptime = $uptime % 3600;
	my $minutes	= int($uptime / 60);	$uptime = $uptime % 60;
	my $seconds	= $uptime;

	$bot->chanmsg( 
		"I have been active for " . 
		($millen  ? $millen  . ' milleni'. ($millen  != 1 ? 'a ' : 'um '):'') .
		($centur  ? $centur  . ' centur' . ($centur  != 1 ? 'ies ':'y '): '') .
		($years   ? $years   . ' year'   . ($years   != 1 ? 's ' : ' ') : '') .
		($days    ? $days    . ' day'    . ($days    != 1 ? 's ' : ' ') : '') .
		($hours   ? $hours   . ' hour'   . ($hours   != 1 ? 's ' : ' ') : '') .
		($minutes ? $minutes . ' minute' . ($minutes != 1 ? 's ' : ' ') : '') .
		($seconds ? ($minutes ? 'and ' : '') . $seconds . ' second' . ($seconds != 1 ? 's'  : '' ) : '')
	);
}

1;

