package PipSqueek::Plugin::Random;
use base qw(PipSqueek::Plugin);
use strict;

#use Data::Dumper;


sub plugin_initialize 
{
    my $self = shift;
    my $c = $self->config();
    
    $self->plugin_handlers([
        'public_farm',
		'private_farm',
		'public_npc',
		'public_ollies',
		'private_ollies',
		'public_gotoollies',
		'public_aerobie',
		'private_aerobie',
		'private_ftest',
		'public_cupcake',
		'public_newfarm',
		'public_weather',
		'public_insult',
		'public_rico',
		'multi_hangover',
                'multi_testerino',
    ]);
	
	my $schema = [
        [ 'id',        'INTEGER PRIMARY KEY' ],
        [ 'available',    'INT NOT NULL' ],
		[ 'user',	'VARCHAR NULL' ],
		[ 'date', 	'DATETIME NULL' ],
    ];

    $self->dbi()->install_schema( 'farm', $schema );
}

sub multi_hangover
{
    my ($self,$message) = @_;

	$self->respond( $message, "What do tigers dream of, when they take a little tiger snooze. Do they dream of mauling zebras, or Halle Berry in her catwoman suit. Don't you worry your pretty stripped head we're gonna get you back to Tyson and your cozy tiger bed." );
	return $self->respond( $message, "And they we're gonna find our bestfriend Doug and then we're gonna give him a bestfriend hug. Doug, Doug, Oh, Doug Douggie Douggie Doug Doug. But if he's been murdered by crystal meth tweekers, well then we're shit out of luck." );
}

sub public_rico
{
	my ($self,$message) = @_;
	return $self->client()->kick( $message->channel(), $message->nick(), "You're out of control" );
}

sub public_farm2
{
    my ($self,$message) = @_;

	return $self->respond( $message, "|meh| chris rico: Farm!!!" );
}

sub public_cupcake
{
    my ($self,$message) = @_;

	return $self->respond( $message, "Have a cupcake." );
}

sub public_farm3
{
	my ($self,$message) = @_;
	my @input = split(/\s+/, $message->command_input());

	if( lc($input[0]) eq 'announce' )
	{
		return $self->respond( $message, "|meh| chris rico: Farm!!!" );
	}
    if( lc($input[0]) eq 'open' )
    {
        my $dbh = $self->dbi()->dbh();

		my $sql = 'UPDATE farm SET available = 1 WHERE id = 1';

		my ($id, $avail) = $dbh->selectrow_array($sql);

		$self->respond( $message, "farm is now open" );
		return;
    }
	
    if( lc($input[0]) eq 'taken' )
    {
        my $dbh = $self->dbi()->dbh();

		my $sql = 'UPDATE farm SET available = 0 WHERE id = 1';

		my ($id, $avail) = $dbh->selectrow_array($sql);

		$self->respond( $message, "farm is now in use" );
		return;
    }
	
	my $dbh = $self->dbi()->dbh();

	my $sql = 'SELECT available FROM farm WHERE id = 1';

	my ($avail) = $dbh->selectrow_array($sql);
	
	if ($avail eq 0)
	{
		$self->respond( $message, "farm is in use" );
	}
	else
	{
		$self->respond( $message, "farm is available" );
	}
	
	return;
}

sub public_ollies
{
	my ($self,$message) = @_;
	my $name = $message->command_input();

#	return $self->respond( $message, "~o $name" );
	return $self->client()->privmsg( "o_Q", "~o $name" );
}

sub public_gotoollies
{
    my ($self,$message) = @_;

	return $self->client()->privmsg( "o_Q", "~ollies" );
}

sub public_ollies_2
{
    my ($self,$message) = @_;

	return $self->respond( $message, "Closed for the season" );
}

sub public_aerobie
{
    my ($self,$message) = @_;

	#return $self->respond( $message, "|meh| chris CromeDome josh josh2_0 junior rico: Aerobie!!!" );
	return $self->respond( $message, "I miss aerobie =/" );
}

sub private_farm
{
    my ($self,$message) = @_;

	return $self->respond( $message, "You'd really be better off performing that in the channel..." );
}

sub private_ollies
{
    my ($self,$message) = @_;

	return $self->respond( $message, "You'd really be better off performing that in the channel..." );
}

sub private_aerobie
{
    my ($self,$message) = @_;

	return $self->respond( $message, "You'd really be better off performing that in the channel..." );
}

sub private_ftest
{
	my ($self,$message) = @_;
	my @input = split(/\s+/, $message->command_input());

    if( lc($input[0]) eq 'open' )
    {
        my $dbh = $self->dbi()->dbh();

		my $sql = 'UPDATE farm SET available = 1 WHERE id = 1';

		my ($id, $avail) = $dbh->selectrow_array($sql);

		$self->respond( $message, "farm is now open" );
		return;
    }
	
    if( lc($input[0]) eq 'taken' )
    {
        my $dbh = $self->dbi()->dbh();

		my $sql = 'UPDATE farm SET available = 0 WHERE id = 1';

		my ($id, $avail) = $dbh->selectrow_array($sql);

		$self->respond( $message, "farm is now in use" );
		return;
    }
	
	my $dbh = $self->dbi()->dbh();

	my $sql = 'SELECT available FROM farm WHERE id = 1';

	my ($avail) = $dbh->selectrow_array($sql);
	
	if ($avail eq 0)
	{
		$self->respond( $message, "farm is in use" );
	}
	else
	{
		$self->respond( $message, "farm is available" );
	}
	
	return;
	
}

sub private_ftest2
{
	my ($self,$message) = @_;

    my $dbh = $self->dbi()->dbh();

    my $sql = 'INSERT INTO farm (id, available) VALUES (1, 1)';

    my ($id, $avail) = $dbh->selectrow_array($sql);

    my $output = sprintf( 
        'id: %d avail %d, ',
        $id, $avail
    );

    $self->respond( $message, $output );
    return;
}

sub public_farm
{
   my ($self,$message) = @_;
   
   return $self->client()->privmsg( "o_Q", "~f" );
}

sub public_npc
{
   my ($self,$message) = @_;

   return $self->client()->privmsg( "o_Q", "~n" );
}


sub public_weather
{
    my ($self,$message) = @_;

	return $self->client()->privmsg( "o_Q", "~w 60178" );
}

sub public_insult
{
    my ($self,$message) = @_;
	my $name = $message->command_input();

	return $self->client()->privmsg( "o_Q", "~b $name" );
}

sub multi_testerino
{
    my ($self,$message) = @_;
        my $name = $message->command_input();

#        return $self->client()->privmsg( $name, "test" );
    return $self->respond($message, "testerino" );
}


1;


__END__
