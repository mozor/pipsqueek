package Handlers::Public::Addme;
#
# This event adds a new user to the database
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_addme'	=> \&public_addme,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Adds the user to the database" if( /public_addme/ );
		}
}


sub public_addme
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');

	unless( $umgr->uid($nick) >= 0 )
	{
		$umgr->adduser( $nick );
		$bot->chanmsg( "Ahoy $nick! [you have been added]" );
		if( defined($event->param('message')->[0]) && $event->param('message')->[0] eq 'please' ) {
			$umgr->param($nick, {'chars' => 5000});
			$bot->chanmsg( 'And for being so polite, 50 points were added to your score.' );
		}
		$umgr->save();
	}
}

1;

