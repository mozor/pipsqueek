package Handlers::Public::Quote;
#
# This package handles the various quote-related handlers
# like !quote, !+quote, !-quote
#
use base 'PipSqueek::Handler';
use strict;
use DBI;

my $dbh;

sub setup
{
	my $self = shift;
	my $file = $self->{'runpath'} . '/data/db/quotes.db';

	if( -e $file ) {
		$dbh = DBI->connect("dbi:SQLite:$file", { 'RaiseError' => 1, 'AutoCommit' => 1 });
	} else {
		$dbh = DBI->connect("dbi:SQLite:$file", { 'RaiseError' => 1, 'AutoCommit' => 1 });
		$dbh->do(q{
			CREATE TABLE quotes (id INTEGER PRIMARY KEY, count INT DEFAULT 0, quote TEXT);
		});
		
		$dbh->do(q{INSERT INTO quotes (id,count,quote) VALUES (0,0,'invisible');});
		# This quote will never get shown, but the code requires it.
		
	}
}

sub teardown
{
	$dbh->disconnect();
}

sub get_handlers 
{
	my $self = shift;
	return {
		'public_quote'	=> \&get_quote,
		'public_+quote' => \&add_quote,
		'public_-quote' => \&del_quote,
		'public_#quote' => \&cnt_quote,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Bot says a quote to the channel" if( /public_quote/ );
		return "Bot reports how many quotes are stored" if( /public_\#quote/ );
		return "Removes a quote from the database" if( /public_\-quote/ );
		return "Adds a new quote to the database" if ( /public_\+quote/ );
	}
}

sub get_usage
{
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "!quote [id|regex]" if ( /public_quote/ );
		return "!+quote <quote text>" if ( /public_\+quote/ );
		return "!-quote <id>" if ( /public_\-quote/ );
		return "!#quote" if ( /public_\#quote/ );
	}
}


sub get_quote
{
	my $bot = shift;
	my $event = shift;

	my $id_to_get = $event->param('message')->[0];

	if( defined($id_to_get) && $id_to_get !~ /[^0-9]/ ) 
	{
		my ($quote) = $dbh->selectrow_array(qq{SELECT quote FROM quotes WHERE id=$id_to_get});
		if( $quote )
		{
			$dbh->do(qq{UPDATE quotes SET count=count+1 WHERE id=$id_to_get});
			return $bot->chanmsg( "$quote (id: $id_to_get)" );
		}
		else
		{
			return $bot->chanmsg( "Quote not found." );
		}
	} 
	else
	{
	my ($count) = $dbh->selectrow_array(q{SELECT COUNT(*) FROM quotes});
		$count -= 1;

		if( defined($count) && $count > 0 ) {
		my $quote;
		my $id;
		do {
			$id = int(rand($count) + 1);
			($quote) = $dbh->selectrow_array(qq{SELECT quote FROM quotes WHERE id=$id});
		} 
		while ( !defined($quote) );

		$dbh->do(qq{UPDATE quotes SET count=count+1 WHERE id=$id});
		return $bot->chanmsg( "$quote (id: $id)" );
	}
	else 
	{
		return $bot->chanmsg( "There are no quotes." );
	}
	}
}


sub add_quote
{
	my $bot = shift;
	my $event = shift;

	my ($id) = $dbh->selectrow_array(
		'SELECT quotes.id+1 FROM quotes WHERE NOT quotes.id+1 IN (SELECT id FROM quotes) LIMIT 1'
	);
	$id ||= 1;

	my $quote = $dbh->quote($event->param('msg'));

	my $sql = qq{INSERT INTO quotes (id,quote,count) VALUES($id,$quote,0)};

	$dbh->do($sql);


	return $bot->chanmsg( "Quote added. (id: $id)" );
}


sub del_quote
{
	my $bot = shift;
	my $event = shift;

	my $id_to_del = $event->param('message')->[0];

	if( $id_to_del =~ /[^0-9]/ ) 
	{
		return $bot->chanmsg( "..." );		
	}
	else 
	{
		my ($test) = $dbh->selectrow_array("SELECT id FROM quotes WHERE id=$id_to_del");
		if( $test ) 
		{
			$dbh->do(qq{DELETE FROM quotes WHERE id=$id_to_del});
			return $bot->chanmsg( "Deleted." );
		}
		else 
		{
			return $bot->chanmsg( "Quote not found." );
		}
	}
}

sub cnt_quote
{
	my $bot = shift;
	my ($count) = $dbh->selectrow_array(q{SELECT COUNT(*) FROM quotes});
	$count -= 1;
	return $bot->chanmsg( 'There ' . ($count != 1 ? 'are' : 'is') . " currently $count quote" . ($count != 1 ? 's.' : '.') );
}


1;


