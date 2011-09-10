package PipSqueek::Plugin::Roulette;
use base qw(PipSqueek::Plugin);
use strict;


sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'public_roulette',
        'private_roulette',
		'public_roulettereload',
        'pipsqueek_mergeuser',
    ]);

    my $schema = [
        [ 'id',        'INTEGER PRIMARY KEY' ],
        [ 'userid',    'INT NOT NULL' ],
        [ 'games',    'INT NOT NULL DEFAULT 0' ],
        [ 'clicks',    'INT NOT NULL DEFAULT 0' ],
        [ 'bangs',    'INT NOT NULL DEFAULT 0' ],
    ];

    $self->dbi()->install_schema( 'roulette', $schema );

    $self->roulette_reload();
}


sub search_roulette_user
{
    my ($self,$message) = @_;

    my $user = $self->search_or_create_user( $message );
    my $info = $self->dbi()->select_record(
            'roulette',
            { 'userid' => $user->{'id'} } 
           );

    unless( $info )
    {
        $info =
        $self->dbi()->create_record(
            'roulette',
            { 'userid' => $user->{'id'}, }
        );
    }

    return $info;
}


sub update_roulette_user
{
    my ($self,$user) = @_;

    $self->dbi()->update_record(
        'roulette',
        $user
    );
}

#--
sub private_roulette
{
    my ($self,$message) = @_;

    $self->respond( $message, "You can only play in the channel!" );

    return;
}


sub public_roulette
{
    my ($self,$message) = @_;
    my @input = split(/\s+/, $message->command_input());

    if( lc($input[0]) eq 'stats' )
    {
        if( $input[1] ) {
            $self->roulette_stats_user( $message, $input[1] );
        } else {
            $self->roulette_stats_global( $message );
        }

        return;
    }

    my $ruser = $self->search_roulette_user( $message );

    my $PLAYERS = $self->{'PLAYERS'};

    if( $PLAYERS->[ $#$PLAYERS ] == $ruser->{'userid'} )
    {
        $self->respond( $message, 
            "You can't pull the trigger twice in a row dolt!" );
        return;
    }

    my $CHAMBERS = $self->{'CHAMBERS'};
    push( @$PLAYERS, $ruser->{'userid'} );

    my $bullet = shift @$CHAMBERS;

    my $output = sprintf( '%s: chamber #%d of 6 => %s',
                  $message->nick(),
                  (6-@$CHAMBERS),
                  $bullet ? '*BANG*' : '+click+'
            );
    
    unless( $bullet || @$CHAMBERS )
    {
        $output .= " ... you lucky bastard?!";
    }

    if( $bullet || (@$CHAMBERS == 0) )
    {
        my %ids = map { $_ => 1 } @$PLAYERS;
        my @ids = keys %ids;

        if( @ids ) 
        {
            local $"=','; 
            my $sql = "UPDATE roulette SET games=games+1 " .
                  "WHERE userid IN (@ids)";
            $self->dbi()->dbh()->do( $sql );
        }

        $ruser->{'games'}++;

        if ($bullet) {
            $ruser->{'bangs'}++;
        }
        else {
            $ruser->{'clicks'}++;
        }
    }
    else
    {
        $ruser->{'clicks'}++;
    }

    $self->update_roulette_user( $ruser );

    #$self->client()->kick( $message->channel(), $message->nick(), $output ) if $bullet;
	#$self->client()->kick( $message->channel(), $message->nick(), "Dead people should stay dead." ) if $bullet;
    $self->respond( $message, $output );
#	$self->respond( $message, "^_^: chamber #1 of 6 => +click+" );
    $self->roulette_reload( $message ) if $bullet || !@$CHAMBERS;

    return;
}


sub roulette_reload
{
    my ($self,$message) = @_;

    my @CHAMBERS = ( 0, 0, 0, 0, 0, 0 );
    @CHAMBERS[rand @CHAMBERS] = 1;

    if( time % 17 == 0 ) {
        @CHAMBERS = ( 0, 0, 0, 0, 0, 0 );
    }

    my @PLAYERS = ();

    $self->{'PLAYERS'} = \@PLAYERS;
    $self->{'CHAMBERS'} = \@CHAMBERS;

    if( $message )
    {
        $self->respond_act( $message, "reloads" );
        return;
    }
}


sub roulette_stats_global
{
    my ($self,$message) = @_;

    my $dbh = $self->dbi()->dbh();

    my $sql = 'SELECT SUM(games), SUM(clicks)+SUM(bangs), COUNT(userid) ' .
          'FROM roulette';

    my ($games,$shots,$players) = $dbh->selectrow_array($sql);

    my $l_sql = 'SELECT u.username, (cast(r.clicks as real)/(cast(r.clicks as real)+cast(r.bangs as real)))*100.000 ' .
             'as percent FROM roulette r, users u ' .
             'WHERE u.id=r.userid AND r.games > 9 ' .
			 'AND (r.clicks + r.bangs) > 0 ' .
             'ORDER BY percent DESC LIMIT 1';
    my (@luckiest) = $dbh->selectrow_array($l_sql);
    
    my $u_sql = 'SELECT u.username, (cast(r.clicks as real)/(cast(r.clicks as real)+cast(r.bangs as real)))*100.000 ' .
             'as percent FROM roulette r, users u ' .
             'WHERE u.id=r.userid AND r.games > 9 ' .
		' AND u.id != 74 ' .
             'ORDER BY percent ASC LIMIT 1';
    my (@unluckiest) = $dbh->selectrow_array($u_sql);

    my $output = sprintf( 
        'roulette stats: %d games completed, ' .
        '%d shots fired at %d players.  ' .
        ($luckiest[0] ? 'Luckiest: %s (%.2f%% clicks).  ' : "") .
        ($unluckiest[0] ? 'Unluckiest: %s (%.2f%% clicks).' : ""),

        $games, $shots, $players, @luckiest, @unluckiest
    );

    $self->respond( $message, $output );
    return;
}


sub roulette_stats_user
{
    my ($self,$message,$username) = @_;
    my $ruser = $self->search_user( $username );

    unless( $ruser )
    {
        $self->respond( $message, "That user does not exist." );
        return;
    }

    my $sql = 'SELECT games, clicks, bangs, (cast(clicks as real)/(cast(clicks as real)+cast(bangs as real)))*100.000 FROM roulette WHERE userid=?';
    my $sth = $self->dbi()->dbh()->prepare( $sql );
       $sth->execute( $ruser->{'id'} );

    my ($games,$clicks,$bangs, $ust) = $sth->fetchrow_array();

    my $output = sprintf(
        '%s has played %d game%s, won %d and lost %d.  ' .
        '%s pulled the trigger %d time%s and found the chamber empty ' .
        'on %d occasion%s. Stats: %.2f%% clicks.',

        $ruser->{'username'}, $games, 
        ($games == 1 ? "" : 's'),
        $games-$bangs, $bangs,
        $ruser->{'username'}, $clicks+$bangs, 
        (($clicks+$bangs) == 1 ? "" : 's'),
        $clicks,
        ($clicks == 1 ? "" : 's'),
		$ust,
        );

    $self->respond( $message, $output );
    return;
}


sub pipsqueek_mergeuser
{
    my ($self,$message,$user1,$user2) = @_;

    my $roulette1 = $self->search_roulette_user( $user1 );
    my $roulette2 = $self->search_roulette_user( $user2 );

    foreach my $category ( qw(games clicks bangs) )
    {
        $roulette1->{$category} += $roulette2->{$category};
    }


    $self->update_roulette_user( $roulette1 );
    $self->dbi()->delete_record( 'roulette', $roulette2 );
}

1;


__END__
