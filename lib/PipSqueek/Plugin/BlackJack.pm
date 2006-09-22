package PipSqueek::Plugin::BlackJack::Deck;

use overload 
    '@{}' => sub { return (shift)->{'cards'}; },
    '""'  => sub { 
            local $" = ' ';
            my $deck = (shift)->{'cards'};
            return "@$deck";
             };
            
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = bless( {}, $class );

    if( @_ ) {
        $self->cards(@_);
    } else {
        $self->cards([]);
    }

    return $self;
}

sub cards
{
    my $self = shift;

    if( @_ ) {
        $self->{'cards'} = ref($_[0]) ? $_[0]      : [@_];
        $self->{'odeck'} = ref($_[0]) ? [@{$_[0]}] : [@_];
    }

    return $self->{'cards'};
}

sub reset { $self->{'cards'} = [ @{$self->{'odeck'}} ]; }

sub cut
{
    my ($self,$index) = @_;
    my $cards = $self->cards();

    unshift( @$cards, splice( @$cards, $index || int(rand($#$cards)+1) ) );
}

sub draw
{
    my ($self) = @_;
    my $cards = $self->cards();

    return pop @$cards;
}

# this algorithm is borrowed from the Algorithm::Numerical::Shuffle package
# It's called the 'fisher yates shuffle'
sub shuffle
{
    my $self = shift;
    my $array = $self->cards();
    return unless @$array;

    my $i = @$array;
    while( --$i )
    {
            my $r = int rand ($i + 1);
        @$array[$i,$r] = @$array[$r,$i];
    }
}

sub add_card
{
    my ($self,$card) = @_;
    my $cards = $self->cards();

    push( @$cards, $card );
}


1;


# ----------------------------------------------------------------------------#
package PipSqueek::Plugin::BlackJack::Card;
use base 'Class::Accessor::Fast';
use overload '""' => sub { (shift)->rank() };

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = bless( {}, $class );

    $self->mk_accessors(qw( rank value ));

    if( @_ )
    {
        $self->rank( shift );
        $self->value( shift );
    }

    return $self;
}


1;


# ----------------------------------------------------------------------------#
package PipSqueek::Plugin::BlackJack;
use base 'PipSqueek::Plugin';
use strict;


sub config_initialize
{
    my $self = shift;

    $self->plugin_configuration({
        'blackjack_starting_bank'    => 500,
        'blackjack_minimum_bet'        => 50,
        'blackjack_maximum_loan'    => 500,
        'blackjack_high_roller'        => 5000,
        'blackjack_number_of_decks'    => 6,
    });
}


sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers({
        'multi_blackjack' => 'multi_blackjack',
        'multi_bj'        => 'multi_blackjack',
        'pipsqueek_mergeuser' => 'pipsqueek_mergeuser',
    });

    my $schema = [
        [ 'id',        'INTEGER PRIMARY KEY' ],
        [ 'userid',    'INT NOT NULL' ],
        [ 'bank',    'INT NOT NULL' ],
        [ 'bet',    'INT NOT NULL' ],
        [ 'player',    'VARCHAR' ],
        [ 'dealer',     'VARCHAR' ],
        [ 'deck',    'VARCHAR' ],
        [ 'high_win',    'INT DEFAULT 0' ],
        [ 'high_loss',    'INT DEFAULT 0' ],
        [ 'games',    'INT DEFAULT 0' ],
    ];

    $self->dbi()->install_schema( 'blackjack', $schema );

    my $conf = $self->config();
    $self->{'STARTING_BANK'} = $conf->blackjack_starting_bank();
    $self->{'MINIMUM_BET'}   = $conf->blackjack_minimum_bet();
    $self->{'MAXIMUM_LOAN'}  = $conf->blackjack_maximum_loan();
    $self->{'HIGH_ROLLER'}   = $conf->blackjack_high_roller();
    $self->{'NUM_DECKS'}     = $conf->blackjack_number_of_decks();
}


sub search_blackjack_user
{
    my ($self,$message) = @_;

    my $user = $self->search_or_create_user( $message );
    my $info = $self->dbi()->select_record(
            'blackjack',
            { 'userid' => $user->{'id'} } 
           );

    if( $info )
    {
        $info->{'deck'}   = $self->thaw_deck( $info->{'deck'} );
        $info->{'player'} = $self->thaw_deck( $info->{'player'} );
        $info->{'dealer'} = $self->thaw_deck( $info->{'dealer'} );
    }

    unless( $info )
    {
        my $deck = $self->create_deck();

        $info =
        $self->dbi()->create_record(
            'blackjack',
            { 'userid' => $user->{'id'},
              'bet'    => 0,
              'bank'   => $self->{'STARTING_BANK'},
              'deck'   => $self->freeze_deck($deck) }
        );

        $info->{'deck'} = $deck;
        $info->{'player'} = PipSqueek::Plugin::BlackJack::Deck->new();
        $info->{'dealer'} = PipSqueek::Plugin::BlackJack::Deck->new();

        $info->{'deck'}->shuffle();
        $info->{'deck'}->cut();
    }

    return $info;
}


sub update_blackjack_user
{
    my ($self,$user) = @_;

    $user->{'deck'}   = $self->freeze_deck($user->{'deck'});
    $user->{'player'} = $self->freeze_deck($user->{'player'});
    $user->{'dealer'} = $self->freeze_deck($user->{'dealer'});

    $self->dbi()->update_record(
        'blackjack',
        $user
    );
}


sub reset_blackjack_user
{
    my ($self,$user) = @_;

    $user->{'deck'} = $self->create_deck();
    $user->{'player'}->cards([]);
    $user->{'dealer'}->cards([]);
    $user->{'bet'} = 0;
    $user->{'bank'} = $self->{'STARTING_BANK'};
}



sub create_deck
{
    my $self = shift;

    my @temp = map { $_ => $_ } ( 2 .. 10 );

    my %cards = (@temp, 'J'=>10,'Q'=>10,'K'=>10,'A'=>11);

    my @deck = ();
    foreach ( 1 .. 4 * $self->{'NUM_DECKS'} )
    {
        foreach my $r ( keys %cards )
        {
            my $v = $cards{$r};
            push( @deck, 
            PipSqueek::Plugin::BlackJack::Card->new($r,$v) );
        }
    }
    
    my $deck = PipSqueek::Plugin::BlackJack::Deck->new( \@deck );
    $deck->shuffle();
    $deck->cut();

    return $deck;
}

sub freeze_deck
{
    my ($self,$deck) = @_;

    my @temp;
    foreach my $card ( @$deck )
    {
        push(@temp, $card->rank() . ':' . $card->value());
    }

    return "@temp";
}
    
sub thaw_deck
{
    my ($self,$frozen) = @_;

    my @temp = split(/ /, $frozen);

    my @deck;
    foreach my $item ( @temp )
    {
        my ($r,$v) = split(/:/, $item);
        my $card = PipSqueek::Plugin::BlackJack::Card->new($r,$v);
        push(@deck,$card);
    }

    return PipSqueek::Plugin::BlackJack::Deck->new( \@deck );
}


sub multi_blackjack
{
    my ($self,$message) = @_;
    my $input = [split(/\s+/, lc($message->command_input()))];

    my $user  = $self->search_blackjack_user( $message );

    if( $input->[0] eq 'stats' )
    {
        my $dbh = $self->dbi()->dbh();
        my $output;

        if( $input->[1] )
        {
            my $buser = $self->search_user( $input->[1] );

            unless( $buser )
            {
                $self->respond( $message, 
                    "That user does not exist" );
                return;
            }

            my $id = $buser->{'id'};

            my @info = $dbh->selectrow_array(
        "SELECT u.username,b.games,b.bank,b.high_win,b.high_loss " .
        "FROM users u, blackjack b WHERE b.userid=u.id AND u.id=$id "
            );

            $output = "Stats for $info[0]:";
            $output.= "  Games played: $info[1].";
            $output.= "  Bank account: \$$info[2].";
            $output.= "  Biggest win: \$$info[3].";
            $output.= "  Biggest loss: \$$info[4].";
        }
        else
        {
            my @rich = $dbh->selectrow_array( 
        "SELECT u.username,b.bank FROM users u, blackjack b " .
        "WHERE b.userid=u.id ORDER BY b.bank DESC LIMIT 1"
            );
            
            my @bigw = $dbh->selectrow_array(
        "SELECT u.username,b.high_win FROM users u, blackjack b " .
        "WHERE b.userid=u.id ORDER BY b.high_win DESC LIMIT 1"
            );
            
            my @bigl = $dbh->selectrow_array(
        "SELECT u.username,b.high_loss FROM users u,blackjack b " .
        "WHERE b.userid=u.id ORDER BY b.high_loss DESC LIMIT 1"
            );
            
            my @most = $dbh->selectrow_array(
        "SELECT u.username,b.games FROM users u, blackjack b " .
        "WHERE b.userid=u.id ORDER BY b.games DESC LIMIT 1"
            );
            
           $output = "Most games played: $most[0] ($most[1] games).";
           $output.= "  Richest player: $rich[0] (\$$rich[1]).";
           $output.= "  Biggest win: $bigw[0] (\$$bigw[1]).";
           $output.= "  Biggest loss: $bigl[0] (\$$bigl[1]).";

        }

        $self->respond( $message, $output );

        return;
    }

    if( $message->event() =~ /^public_/ )
    {
        my $HIGH_ROLLER = $self->{'HIGH_ROLLER'};
        unless( $user->{'bank'} >= $HIGH_ROLLER )
        {
            $self->respond( $message, 
            "I'm sorry, only high-rollers (users with more than " .
            "\$$HIGH_ROLLER in the bank) can play in the channel");
            return;
        }
    }

    if( $input->[0] =~ m/^(\d+)$/ )
    {
        $input->[0] = 'bet';
        $input->[1] = $1;
    }

    if( $input->[0] eq 'bet' )
    {
        $self->blackjack_bet( $message, $user, $input );
        $self->update_blackjack_user( $user );
        return;
    }
    elsif( $input->[0] eq 'hit' )
    {
        $self->blackjack_hit( $message, $user );
        $self->update_blackjack_user( $user );
        return;
    }
    elsif( $input->[0] eq 'double' )
    {
        $self->blackjack_doubledown( $message, $user );
        $self->update_blackjack_user( $user );
        return;
    }
    elsif( $input->[0] eq 'stand' )
    {
        $self->blackjack_stand( $message, $user );
        $self->update_blackjack_user( $user );
        return;
    }
    elsif( $input->[0] eq 'status' )
    {
        $self->blackjack_status( $message, $user );
        return;
    }
    elsif( $input->[0] eq 'reset' )
    {
        $self->reset_blackjack_user( $user );
        $self->update_blackjack_user( $user );
        $self->respond( $message, "Your status has been reset" );
        return;
    }
    elsif( $input->[0] eq 'bank' )
    {
        my $bank = $user->{'bank'};
        $self->respond( $message, "You have \$$bank in the bank" );
        return;
    }
    elsif( $input->[0] eq 'hint' )
    {
        $self->blackjack_hint( $message, $user );
        return;
    }

    # if we got here, then we didn't recognize the command
    $self->respond( $message, "Invalid command, use !help bj" );
    return;
#    elsif( $input[0] eq 'split' ) { }
}


sub blackjack_deal
{
    my ($self,$message,$user) = @_;

    if( @{$user->{'deck'}} <= rand(40)+12 )
    {
        $self->blackjack_shuffle( $message, $user );
    }

    $user->{'player'}->add_card( $user->{'deck'}->draw() );
    $user->{'dealer'}->add_card( $user->{'deck'}->draw() );
    $user->{'player'}->add_card( $user->{'deck'}->draw() );
    $user->{'dealer'}->add_card( $user->{'deck'}->draw() );
}

sub blackjack_shuffle
{
    my ($self,$message,$user) = @_;

    $self->respond( $message, "Shuffling the deck..." );

    $user->{'deck'} = $self->create_deck();
    $user->{'deck'}->shuffle();
    $user->{'deck'}->cut();
}


sub blackjack_new_round
{
    my ($self,$message,$user) = @_;

    $user->{'player'}->cards( [] );
    $user->{'dealer'}->cards( [] );
    $user->{'bet'} = 0;

    $user->{'games'}++;
}


sub blackjack_bet
{
    my ($self,$message,$user,$input) = @_;
    
    if( $user->{'bet'} )
    {
        $self->respond( $message, 
        "You must finish playing your current hand before you can bet"
        );
        return;
    }

    my $bet = $input->[1];

    unless( defined($bet) && $bet =~ /^\d+$/ )
    {
        $self->respond( $message, "Invalid bet" );
        return;
    }

    my $MINIMUM_BET = $self->{'MINIMUM_BET'};
    my $MAXIMUM_LOAN = $self->{'MAXIMUM_LOAN'};
    unless( $bet >= $MINIMUM_BET )
    {
        $self->respond( $message,
                "You have to bet at least \$$MINIMUM_BET" );
        return;
    }


    if( $user->{'bank'} <= 0 )
    {
        unless( $bet <= $MAXIMUM_LOAN )
        {
            $self->respond( $message,
                "Since you're in the hole, you can only bet ".
                "up to \$$MAXIMUM_LOAN at a time" );

            return;
        }
    }
    else
    {
        unless( $bet <= $user->{'bank'} )
        {
            $self->respond( $message,
                "You don't have enough to cover that bet" );
            return;
        }
    }

    $bet =~ s/^0+//;

    $user->{'bet'} = $bet;

    $self->blackjack_deal( $message, $user );

    my $player = $user->{'player'};
    my $d_card = $user->{'dealer'}->cards()->[0];

    my $pvalue = $self->blackjack_value( $player );
    my $dvalue = $self->blackjack_value( $user->{'dealer'} );

    local $" = ', ';
    my $output = "You are dealt: @$player (Total: $pvalue)";
       $output .= " - Dealer is showing: $d_card";
    $self->respond( $message, $output );

    if( $dvalue == 21 || $pvalue == 21 )
    {
        $self->blackjack_pay_table( $message, $user );
        $self->blackjack_new_round( $message, $user );
        return;
    }

    return;
}


sub blackjack_status
{
    my ($self,$message,$user) = @_;

    my $bet = $user->{'bet'};
    my $bank = $user->{'bank'};
    my $player = $user->{'player'};
    my $dealer = $user->{'dealer'};
    my $d_card = $dealer->cards()->[0];
    my $pvalue = $self->blackjack_value( $player );
    
    local $" = ', ';
    my $output = "You have \$$bank in the bank.";

    if( $user->{'bet'} )
    {
        $output.= "  You bet \$$bet on this hand.";
        $output.= "  Your hand: @$player (Total: $pvalue).";
        $output.= "  Dealer is showing: $d_card";

    }
    else
    {
        $output.= "  You are not in the middle of a hand";
    }

    $self->respond( $message, $output );
}


sub blackjack_hit
{
    my ($self,$message,$user) = @_;

    unless( $user->{'bet'} )
    {
        $self->respond( $message, "You must bet first!" );
        return;
    }
    
    my $player = $user->{'player'};
       $player->add_card( $user->{'deck'}->draw() );

    my $pvalue = $self->blackjack_value( $player );

    local $" = ', ';
    my $output = "Your hand: @$player (Total: $pvalue)";
    $self->respond( $message, $output );

    if( $pvalue > 21 ) # player busted
    {
        $self->blackjack_pay_table($message,$user);
        $self->blackjack_new_round($message,$user);
        return 0;
    }

    if( $pvalue == 21 )
    {
        $self->blackjack_stand( $message, $user );
        return 2;
    }

    return 1;
}


sub blackjack_doubledown
{
    my ($self,$message,$user) = @_;

    unless( $user->{'bet'} )
    {
        $self->respond( $message, "You must bet first!" );
        return;
    }

    if( @{$user->{'player'}} > 2 )
    {
        $self->respond( $message, 
            "You can only double down with 2 cards in your hand" );
        return;
    }

    my $pvalue = $self->blackjack_value( $user->{'player'}, 'soft' );

    unless( $pvalue >= 9 && $pvalue <= 11 )
    {
        $self->respond( $message,
        "You can only double down when your total is 9, 10, or 11");
        return;
    }

    if( $user->{'bet'}*2 > $user->{'bank'} )
    {
        $self->respond( $message,
            "You don't have enough to cover that bet" );
        return;
    }

    my $MAXIMUM_LOAN = $self->{'MAXIMUM_LOAN'};
    if( $user->{'bank'} <= 0 && $user->{'bet'} > ($MAXIMUM_LOAN/2) )
    {
        $self->respond( $message,
            "You can only bet a maximum of \$$MAXIMUM_LOAN when " .
            "you are in the hole" );
        return;
    }

    $user->{'bet'} *= 2;

    if( $self->blackjack_hit( $message, $user ) == 1 )
    {
        $self->blackjack_stand( $message, $user );
    }
}


sub blackjack_stand
{
    my ($self,$message,$user) = @_;

    unless( $user->{'bet'} )
    {
        $self->respond( $message, "You must bet first!" );
        return;
    }

    my $dealer = $user->{'dealer'};
    while( $self->blackjack_value( $dealer ) < 17 )
    {
        $dealer->add_card( $user->{'deck'}->draw() );
    }

    my $dvalue = $self->blackjack_value( $dealer );

    local $" = ', ';
    my $output = "Dealer's hand: @$dealer (Total: $dvalue)";
    $self->respond( $message, $output );

    $self->blackjack_pay_table($message,$user);
    $self->blackjack_new_round($message,$user);

    return;
}


sub blackjack_value
{
    my ($self,$hand,$soft) = @_;

    my $total = 0;
    my @aces = ();

    foreach my $card ( @$hand )
    {
        my $value = $card->value();
        if( $card->rank() eq 'A' )
        {
            push(@aces,$card);
        }
        $total += $value;
    }

    if( $total > 21 || $soft )
    {
        foreach my $ace (@aces)
        {
            $total -= 10;
            last if $total <= 21 && !$soft;
        }
    }

    return $total;
}


sub blackjack_pay_table
{
    my ($self,$message,$user) = @_;

    my $dv = $self->blackjack_value( $user->{'dealer'} );
    my $pv = $self->blackjack_value( $user->{'player'} );

    my $bet  = $user->{'bet'};

    my $output;

    my $p_num_cards = @{$user->{'player'}};

    my ($six,$sev,$eig) = (0,0,0);  # ...
    my $all_sevens = 0;        # special winning conditions

    if( $pv == 21 && $p_num_cards == 3 )
    {
        my @cards = @{$user->{'player'}};

        $all_sevens = 1;
        foreach my $card (@cards)
        {
               if( $card->value() == 6 ) { $six = 1; }
            elsif( $card->value() == 7 ) { $sev = 1; }
            elsif( $card->value() == 8 ) { $eig = 1; }

            unless( $card->value() == 7 )
            {
                $all_sevens = 0;
            }
        }
    }


    if( $all_sevens )
    {
        my $win = $bet * 3;
        $output = "Bonus payment rule in effect: ";
        $output.= "Triple 7's! You win \$$win!";

        $user->{'bank'} += $win;
        $user->{'high_win'} = $win if $win > $user->{'high_win'};
    }
    elsif( $six && $sev && $eig )
    {
        my $win = $bet * 2;
        $output = "Bonus payment rule in effect: ";
        $output.= "8,7,6 straight! You win \$$win!";

        $user->{'bank'} += $win;
        $user->{'high_win'} = $win if $win > $user->{'high_win'};
    }
    elsif( $p_num_cards >= 5 && $pv <= 21 )
    {
        my $mul = 2**($p_num_cards-4);
        my $win = $bet * $mul;

        $output = "Bonus payment rule in effect: ";
        $output.= "$p_num_cards-Card-Charlie! You win \$$win!";

        $user->{'bank'} += $win;
        $user->{'high_win'} = $win if $win > $user->{'high_win'};
    }
    elsif( $pv > 21 )
    {
        $output = "You bust and lose \$$bet";
        $user->{'bank'} -= $bet;
        $user->{'high_loss'} = $bet if $bet > $user->{'high_loss'};
    }
    elsif( $dv > 21 )
    {
        $output = "Dealer busts! You win \$$bet";
        $user->{'bank'} += $bet;
        $user->{'high_win'} = $bet if $bet > $user->{'high_win'};
    }
    elsif( ($pv <=> $dv) == 0 )
    {
        $output = "You push!";
    }
    elsif( $pv == 21 && @{$user->{'player'}} == 2 )
    {
        my $win = $bet * 1.5;
        $output = "Blackjack! You win \$$win";
        $user->{'bank'} += $win;
        $user->{'high_win'} = $win if $win > $user->{'high_win'};
    }
    elsif( $dv == 21 && @{$user->{'dealer'}} == 2 )
    {
        $output = "Dealer gets blackjack! You lose \$$bet";
        $user->{'bank'} -= $bet;
        $user->{'high_loss'} = $bet if $bet > $user->{'high_loss'};
    }
    elsif( ($pv <=> $dv) == 1 )
    {
        $output = "You win \$$bet";
        $user->{'bank'} += $bet;
        $user->{'high_win'} = $bet if $bet > $user->{'high_win'};
    }
    elsif( ($pv <=> $dv) == -1 )
    {
        $output = "You lose \$$bet";
        $user->{'bank'} -= $bet;
        $user->{'high_loss'} = $bet if $bet > $user->{'high_loss'};
    }

    $self->respond( $message, $output );
}


# gives a hint on what the player should do next in the game
sub blackjack_hint
{
    my ($self,$message,$user) = @_;

    unless( $user->{'bet'} )
    {
        $self->respond( $message, "You need to bet first" );
        return;
    }

    my $dealer = $user->{'dealer'};
    my $player = $user->{'player'};

    my $dv  = $self->blackjack_value( $dealer );
    my $pv  = $self->blackjack_value( $player );
    my $spv = $self->blackjack_value( $player, 'soft' );

    my @dc = @$dealer;
    my @pc = @$player;

    my $dcv = $dc[0]->value();

    # if we have enough cash to double-down, let's evaluate in that context
    if( $user->{'bank'} >= $user->{'bet'}*2 )
    {
        if( ( ($pv == 11) )
         || ( ($pv == 10) && ($dcv != 10 && $dcv != 11) )
         || ( ($pv ==  9) && ($dcv >=  2 && $dcv <=  6) ) )
        {
            $self->respond( $message,
                "You should double down on this bet" );
            return;
        }
    }

    if( ( ($spv != $pv           ) && ($pv >= ($_=18)) )
     || ( ($dcv >= 7             ) && ($pv >= ($_=17)) )
     || ( ($dcv >= 4 && $dcv <= 6) && ($pv >= ($_=12)) )
     || ( ($dcv == 2 || $dcv == 3) && ($pv >= ($_=13)) ) )
    {
         $self->respond( $message, "You should stand on $pv" );
    }
    else
    {
        $self->respond( $message, "Hit until you get $_ or better" );
    }

    return 1;
}


# a little trick to make it nicer when outputting in the public channel
sub respond
{
    my ($self,$message,@rest) = @_;

    if( $message->event() =~ /^public_/ )
    {
        $self->SUPER::respond_user( $message, @rest );
    }
    else
    {
        $self->SUPER::respond( $message, @rest );
    }
}


# merge user2 into user1 and delete user2's information
sub pipsqueek_mergeuser
{
    my ($self,$message,$user1,$user2) = @_;

    my $stats1  = $self->search_blackjack_user( $user1 );
    my $stats2  = $self->search_blackjack_user( $user2 );

    $stats1->{'bank'} += $stats2->{'bank'};

    $stats1->{'deck'} = $self->create_deck();
    $stats1->{'deck'}->shuffle();
    $stats1->{'deck'}->cut();
    
    $stats1->{'player'} = PipSqueek::Plugin::BlackJack::Deck->new();
    $stats1->{'dealer'} = PipSqueek::Plugin::BlackJack::Deck->new();

    $stats1->{'bet'} = 0;

    unless( $stats1->{'high_win'} >= $stats2->{'high_win'} )
    {
        $stats1->{'high_win'} = $stats2->{'high_win'};
    }

    unless( $stats1->{'high_loss'} >= $stats2->{'high_loss'} )
    {
        $stats1->{'high_loss'} = $stats2->{'high_loss'};
    }

    $stats1->{'games'} += $stats2->{'games'};


    $self->update_blackjack_user( $stats1 );

    $self->dbi()->delete_record( 'blackjack', $stats2 );
}


1;


__END__
