package PipSqueek::Plugins::Roulette;
use base qw(PipSqueek::Plugin);

my @CHAMBERS;
my $PLAYERS;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'public_roulette',
		'private_roulette',
	]);

	$self->reload();
}

sub plugin_teardown { }

sub public_roulette
{
	my ($self,$message,@arguments) = @_;

	if( lc($arguments[0]) eq 'stats' )
	{
		$self->roulette_stats( $message, @arguments );
	}
	else
	{
		my $bullet = shift(@CHAMBERS);
		if( $message->nick() eq 'Cyon' ) { $bullet = 0 }
		my $output = sprintf(
			'%s: chamber #%d of 6 => %s',
			$message->nick(),
			(6-@CHAMBERS),
			$bullet ? '*BANG*' : '+click+'
		);

		if( !$bullet && !@CHAMBERS )
		{
			$output .= " ... wtf?!";
		}

		my ($user,$uid) = $self->find_user($message);
		my $stats = $user->{'roulette'} ||= {};

		if( $bullet )
		{
			$stats->{'games'}++;
			$stats->{'bangs'}++;

			my $udb = $self->userdb();
			foreach (keys %$PLAYERS)
			{
				next if $_ eq $uid;
				$udb->{$_}->{'roulette'}->{'games'}++;
			}
		}
		else
		{
			$stats->{'clicks'}++;
			$PLAYERS->{$uid} = 1;
		}

		$self->respond( $message, $output );
		$self->reload($message) if $bullet || !@CHAMBERS;
	}
}

sub reload
{
	my ($self,$message) = @_;
	@CHAMBERS = ( 0, 0, 0, 0, 0, 0 );
	@CHAMBERS[rand @CHAMBERS] = 1;

	if( time % 23 == 0 ) {
		@CHAMBERS = ( 0, 0, 0, 0, 0, 0 );
	}

	$PLAYERS = {};
	if( $message ) {
		return $self->respond_act( $message,  "reloads" );
	}
}

sub roulette_stats_user
{
	my ($self,$message,$username) = @_;
	if( my $user = $self->find_user($username) )
	{
		my ($clicks,$bangs,$games) = map { 
			$user->{'roulette'}->{$_} || 0
		} qw(clicks bangs games);

		my $output  = 
			sprintf(
"%s has played %d games, won %d and lost %d.  " .
"%s pulled the trigger %d times and found the chamber empty on %d occasions",
				$user->{'username'},
				$games,
				$games-$bangs,
				$bangs,
				$user->{'username'},
				$clicks+$bangs,
				$clicks,
			);

		return $self->respond( $message, $output );
	}
	else
	{
		return $self->respond( $message, "That user does not exist" );
	}
}

sub roulette_stats
{
	my ($self,$message,@arguments) = @_;

	if( defined($arguments[1]) )
	{
		return $self->roulette_stats_user($message,$arguments[1]);
	}
	else
	{
		return $self->roulette_stats_totals($message);
	}
}

sub roulette_stats_totals
{
	my ($self,$message) = @_;

	my $udb = $self->userdb();

	my $total_players;
	my $total_games;
	my $total_shots;
	my @died_most;
	my @won_most;
			
	my @h_win_percent;
	my @l_win_percent;
	my @h_luck_percent;
	my @l_luck_percent;

	foreach my $key ( keys %$udb )
	{
		my $user = $udb->{$key};
		next unless exists $user->{'roulette'};

		my $stats = $user->{'roulette'};

		$total_players++;
		$total_games += $stats->{'bangs'};
		$total_shots += $stats->{'bangs'} + $stats->{'clicks'};

		next unless $stats->{'games'} > 2;
		
		my $games_won = $stats->{'games'} - $stats->{'bangs'};
		my $win_rate = ($games_won/$stats->{'games'})*100;
		if( !@h_win_percent || ( $win_rate > $h_win_percent[1] ) )
		{
			@h_win_percent = ($user,$win_rate);
		}
	
		if( !@l_win_percent || ( $win_rate < $l_win_percent[1] ) )
		{
			@l_win_percent = ($user,$win_rate);
		}

		if( ($stats->{'clicks'}+$stats->{'bangs'}) )
		{
			my $luck = ($stats->{'clicks'}/($stats->{'clicks'}+$stats->{'bangs'}))*100;
			if( !@h_luck_percent || ( $luck > $h_luck_percent[1] ) )
			{
				@h_luck_percent = ($user,$luck);
			}
	
			if( !@l_luck_percent || ( $luck < $l_luck_percent[1] ) )
			{
				@l_luck_percent = ($user,$luck);
			}
		}

		if( !@died_most || $stats->{'bangs'} > $died_most[1] )
		{
			@died_most = ($user,$stats->{'bangs'});
		}

		if( !@won_most || $games_won > $won_most[1] )
		{
			@won_most = ($user,$stats->{'games'}-$stats->{'bangs'});
		}
	}

	unless( $total_games )
	{
		return $self->respond( $message, "No games have been played" );
	}

	my $output = sprintf( 
		'roulette stats: %d games completed, ' .
		'%d shots fired at %d players.  ' .
		'Luckiest: %s (%.2f%% clicks).  ' .
		'Unluckiest: %s (%.2f%% clicks).  ' .
		'Highest survival rate: %s (%.2f%%).  ' .
		'Lowest survival rate: %s (%.2f%%).  ' .
		'Most wins: %s (%d).  ' .
		'Most deaths: %s (%d).',

		$total_games,
		$total_shots,
		$total_players,
		$h_luck_percent[0]->{'username'}, $h_luck_percent[1],
		$l_luck_percent[0]->{'username'}, $l_luck_percent[1],
		$h_win_percent[0]->{'username'}, $h_win_percent[1],
		$l_win_percent[0]->{'username'}, $l_win_percent[1],
		$won_most[0]->{'username'}, $won_most[1],
		$died_most[0]->{'username'}, $died_most[1]
	);

	return $self->respond( $message, $output );
}



sub private_roulette
{
	my ($self,$message) = @_;
	return $self->respond( $message,
		"You must play roulette in the channel!" );
}


1;


