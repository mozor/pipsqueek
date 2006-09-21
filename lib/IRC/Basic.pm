package Handlers::IRC::Basic;
#
# This package handles the basic channel and user events like:
#	join, part, nick, topic, 474, kick, mode, quit, 353
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'irc_join'	=> \&irc_join,
		'irc_part'	=> \&irc_part,
		'irc_nick'	=> \&irc_nick,
		'irc_topic'	=> \&irc_topic,
		'irc_474'	=> \&irc_474,
		'irc_kick'	=> \&irc_kick,
		'irc_mode'	=> \&irc_mode,
		'irc_quit'	=> \&irc_quit,
		'irc_353'	=> \&irc_353,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;

	foreach ($type)
	{
		return "Received when a user joins the channel" if( /irc_join/ );
		return "Received when a user parts the channel" if( /irc_part/ );
		return "Received when a user changes his nick." if( /irc_nick/ );
		return "Received when a user changes the topic" if( /irc_topic/ );
		return "This event is posted if we are banned from a channel we try to join" if( /irc_474/ );
		return "Received when a user is kicked from the channel" if( /irc_kick/ );
		return "Received when a user/(or you) changes a mode" if( /irc_mode/ );
		return "Received when a user quits the server, or is /killed" if( /irc_quit/ );
		return "Received when we join a channel, contains the names of the people on the channel" if( /irc_353/ );
	}
}


sub irc_join
# received whenever someone joins a channel we're in
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');
	my $chan = $event->param('channel');

	if( $nick eq $bot->param('nickname') )	
	{ # if it was us that joined
		print "Joined $chan\n";

		if( $bot->param('revenge') )
		{ # if we would like to 0wn people that kicked us from the channel
			if( my $enemies = $bot->enemies() )
			{
				foreach my $enemy ( @{$enemies} )
				{
					my @reasons = (
						qq(j00 have been 0wned, sucka),
						qq(ph33r.  th3.  k1ck.),
						qq(Quick, someone place a ban!),
						qq(Jolt Cola. Shockingly Refreshing!),
						qq(You <censored> piece of <censored> <censored>, I'll <censored> on your mother's grave!),
					);
					$bot->kick( $chan, $enemy, $reasons[rand @reasons] ); # booya!
				}
			}
		}

		return 1;
	}

	$umgr->param( $nick, {'active' => 1, 'seen' => time()} );
	# we've seen this user now, he's active

	if( my $greeting = $bot->param('greeting') )
	{ # display an annoying onjoin message to this user
		$greeting =~ s/::nick::/$nick/g;
		$bot->privmsg( $chan, $greeting );
	}

	return 1;
}



sub irc_kick
# someone (maybe us!) was kicked from the channel
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $kicker = $event->param('nick');
	my $chan = $event->param('channel');
	my $kickee = $event->param('message')->[0];

	if( $kickee eq $bot->param('nickname') )
	{ # They kicked us from the channel!  HOW DARE THEY?!@#$
		push( @{$bot->{'kernel'}->get_active_session()->get_heap()->{'enemies'}}, $kicker ) if $bot->param('revenge');
		$bot->join($chan);
	}
	else
	{
		my $kickee_total_kicked = $umgr->param( $kickee, 'kicked' ) + 1;
		$umgr->param( $kickee, { 
			'active' => 0, 
			'kicked' => $kickee_total_kicked,
			'seen' => time()
		});
		# update the number of times that person got kicked
		
		my $kicker_total_kicks = $umgr->param( $kicker, 'kicks' ) + 1;
		$umgr->param( $kicker, { 'kicks' => $kicker_total_kicks } );
		# update the number of times the kicker has kicked someone
	}
}



sub irc_mode
# someone set a channel mode or a user mode
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');
	return if $nick eq $bot->param('nickname');

	$umgr->param( $nick, { 'modes' => $umgr->param($nick,'modes')+1 } );
}



sub irc_nick
# someone changed their nickname
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $old = $event->param('nick');
	my $new = $event->param('message')->[0];

	$umgr->nick_change($old,$new);
}



sub irc_part
# someone has left the channel!
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;
	
	my $nick = $event->param('nick');
	return if $nick eq $bot->param('nickname');

	$umgr->param( $nick, { 'active' => 0, 'seen' => time() } );
}



sub irc_quit
# someone quit the server!
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');
	$umgr->param( $nick, { 'active' => 0, 'seen' => time() } );

}



sub irc_topic
# someone changed the topic!
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');
	return if $nick eq $bot->param('nickname');

	$umgr->param( $nick, { 'topics' => $umgr->param($nick,'topics')+1 } );
}



sub irc_474
# we're banned from a channel we tried to join!
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $chan = $event->param('channel');

	if( $bot->param('autorejoin') ) {
		if( $bot->param('chanserv') ) {
			$bot->privmsg( 'ChanServ', qq(UNBAN $chan) );
		}
		$bot->join($chan);
	}
}



sub irc_353
# the names of the people on the channel we just joined
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;
	
	foreach ( @{$event->param('message')} )
	{
		s/^.// if /^[\^\+\@\%]/;
		$umgr->param( $_, { 'active' => 1, 'seen' => time() } );
	}
}



1;



