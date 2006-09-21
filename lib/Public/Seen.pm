package Handlers::Public::Seen;
#
# This handler tells us when the bot last saw a user
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_seen' => \&public_seen,
	};
}


sub get_description 
{ 
	"Tells you when the user was last seen";
}

sub get_usage
{
	"!seen <username>";
}


sub public_seen
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $caller = $event->param('nick');
	my $requested = $event->param('message')->[0];
	return unless( $requested );
	
	if( lc $caller eq lc $requested ) {
		return $bot->chanmsg( "Looking for yourself, eh $caller?" );
	}

	if( lc $requested eq lc $bot->param('nickname') ) {
		return $bot->chanmsg( "You found me, $caller!" );
	}
	
	if( my $user = $umgr->user($requested) )
	{
		my $seentime = time() - $user->{'seen'};

		if( $user->{'active'} ) {
			return $bot->chanmsg( "$requested is on the channel right now!" );
		}
		

		my $days    = int($seentime / 86400);	$seentime = $seentime % 86400;
		my $years   = int(    $days / 365 );	$days     = $days     % 355;
		my $centur  = int(   $years / 100 );	$years    = $years    % 100;
		my $millen  = int(  $centur / 10 );	$centur   = $centur   % 10;
		my $hours   = int($seentime / 3600);	$seentime = $seentime % 3600;
		my $minutes = int($seentime / 60);	$seentime = $seentime % 60;
		my $seconds = $seentime;

		$bot->chanmsg( 
			"I last saw $requested " . 
			($millen  ? $millen  . ' milleni'. ($millen  != 1 ? 'a ' : 'um '):'') .
			($centur  ? $centur  . ' centur' . ($centur  != 1 ? 'ies ':'y '): '') .
			($years   ? $years   . ' year'   . ($years   != 1 ? 's ' : ' ') : '') .
			($days    ? $days    . ' day'    . ($days    != 1 ? 's ' : ' ') : '') .
			($hours   ? $hours   . ' hour'   . ($hours   != 1 ? 's ' : ' ') : '') .
			($minutes ? $minutes . ' minute' . ($minutes != 1 ? 's ' : ' ') : '') .
			($seconds ? ($minutes ? 'and ' : '') . $seconds . ' second' . ($seconds != 1 ? 's'  : '' ) : '') .
			' ago.'
		);
	}
	else
	{
		$bot->chanmsg( "That user is not in my database." );
	}
}

1;

