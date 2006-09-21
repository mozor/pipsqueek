package Handlers::Public::Stats;
#
# This package handles the various stats-related public handlers
# like !score, !stats, !rank, !top10
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_rank'	=> \&public_rank,
		'public_score'	=> \&public_rank,	# pretty useless, since !rank does same thing with more info
		'public_top10'	=> \&public_top10,
		'public_stats'	=> \&public_stats,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Returns a user's rank and score" if( /public_rank/ || /public_score/ );
		return "Returns the 10 highest scoring users" if( /public_top10/ );
		return "Returns personal user stats for the user" if( /public_stats/ );
	}
}


sub public_rank
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $requested = $event->param('message')->[0] || $event->param('nick');
	my $userlist = $umgr->get_all_users();
	my @message = @{ $event->param('message') };

	my @list =	reverse sort { $a->{'chars'} <=> $b->{'chars'} } @$userlist;

	if( $requested !~ /[^0-9]/ )
	{
		if( $message[0] > ($#list+1) ) {
			my $t = $event->param('type'); 
			$t =~ s/public_//;	# pretty print based on command called (!rank or !score)
			$bot->chanmsg( ucfirst($t) . ' not found.' );
			return;
		}
		
		my $user = $list[$message[0]-1];
		my $nick = $user->{'original'};
		my $score = $user->{'chars'} / 100;
		$bot->chanmsg( "Rank $message[0]: $nick ($score)" );
	}
	else
	{
		if( my $user = $umgr->user( $requested ) )
		{
			my $rank = 1;
			foreach my $u (@list) {
				if( lc($u->{'nick'}) eq lc($requested) )
				{
					my $score = $u->{'chars'} / 100;
					my $nick = $u->{'original'};
					$bot->chanmsg( "Rank $rank: $nick ($score)" );
					return;
				}
				$rank++;
			}

			foreach my $u (@list) {
				if( lc($u->{'original'}) eq lc($requested) )
				{
					my $score = $u->{'chars'} / 100;
					my $nick = $u->{'original'};
					$bot->chanmsg( "Rank $rank: $nick ($score)" );
					return;
				}
				$rank++;
			}
		}
		else
		{
			$bot->chanmsg( 'User not found.' );
		}
	}
}


sub public_stats
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $requested = $event->param('message')->[0] || $event->param('nick');

	if( my $user = $umgr->user($requested) )
	{
		my $nick = $user->{'original'};
		my $lines = $user->{'lines'};
		my $words = $user->{'words'};
		my $chars = $user->{'chars'};
		my $smiles = $user->{'smiles'};
		my $actions = $user->{'actions'};
		my $modes = $user->{'modes'};
		my $topics = $user->{'topics'};
		my $kicks = $user->{'kicks'};
		my $kicked = $user->{'kicked'};

		$bot->chanmsg( 
			"$nick: $words words, $lines lines, $actions actions, $smiles smiles, " .
			"kicked $kicks lusers, been kicked $kicked times, set $modes modes, changed the topic $topics times."
		);
	}
	else
	{
		$bot->chanmsg( "User not found." );
	}
}


sub public_top10
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my @users = @{$umgr->get_all_users};
	my @top10;
	foreach my $user ( reverse sort { $a->{'chars'} <=> $b->{'chars'} } @users )
	{
		my $score = $user->{'chars'} / 100;
		my $nick = $user->{'original'};
		my $x = "$nick ($score)";
		push(@top10, $x) if $#top10 != 10;
		last if $#top10 == 10;
	}
	
	if( scalar(@top10) == 0)
	{
		$bot->chanmsg("There are no users!");
		return;
	}
	
	my $message = 'Top10: ' . join(', ',@top10) . '!';
	$bot->chanmsg( $message );
}


1;


