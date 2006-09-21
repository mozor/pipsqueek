package PipSqueek::Plugins::Quotes;
use base qw(PipSqueek::Plugin);
use strict;

use DBI;
use File::Spec::Functions;

my $Queries = {
'create' => 'CREATE TABLE quotes (id INTEGER PRIMARY KEY, quote TEXT)',
'select_all_ids' => 'SELECT id FROM quotes',
'select_search' => 'SELECT id,quote FROM quotes WHERE quote LIKE ?',
'select_exact' => 'SELECT id,quote FROM quotes WHERE id=?',
'insert' => 'INSERT INTO quotes (id,quote) VALUES (?,?)',
'delete' => 'DELETE FROM quotes WHERE id=?',
};

my $dbh;
my %IDS = ();

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers(
		'multi_quote'  => 'get_quote',
		'multi_+quote' => 'add_quote',
		'multi_-quote' => 'del_quote',
		'multi_#quote' => 'cnt_quote',
	);

	my $file = catfile( $self->cwd(), '/var/quotes.db' );

	if( -e $file ) 
	{
		$dbh = DBI->connect("dbi:SQLite:$file", 
			{ 'RaiseError' => 1, 'AutoCommit' => 1 });
	}
	else 
	{
		$dbh = DBI->connect("dbi:SQLite:$file", 
			{ 'RaiseError' => 1, 'AutoCommit' => 1 });
		$dbh->do( $Queries->{'create'} );
	}

	my $rows = $dbh->selectall_arrayref( $Queries->{'select_all_ids'} );
	if( @$rows ) {
		%IDS = map { $_->[0] => 1 } @$rows;
	}
}

sub plugin_teardown { }

sub get_quote
{
	my ($self,$message) = @_;
	my ($pattern_or_id) = $message->message() =~ m/quote\s+(.+)$/;

	unless( keys %IDS )
	{
		return $self->respond( $message, "There are no quotes." );
	}
	
	unless( defined $pattern_or_id )
	{
		# random quote
		my @IDS = keys %IDS;
		my $sth = $dbh->prepare( $Queries->{'select_exact'} );
			  $sth->execute( @IDS[rand @IDS] );
		my ($id,$quote) = $sth->fetchrow_array();
		return $self->respond( $message, "$quote (id: $id)" );
	}

	if( $pattern_or_id =~ /[^\d]/ )
	{
		# search on pattern
		my $sth = $dbh->prepare( $Queries->{'select_search'} );
			  $sth->execute( "\%$pattern_or_id\%" );
		my $rows = $sth->fetchall_arrayref();

		if( @$rows > 1 )
		{
			local $"=', ';
			my @ids = map { $_->[0] } @$rows;
			return $self->respond( $message,
				"Found ". @ids . " matching ids: @ids." );
		}
		elsif( @$rows == 1 )
		{
			my ($id, $quote) = @{ $rows->[0] };
			return $self->respond( $message, "$quote (id: $id)" );
		}
		else
		{
			return $self->respond( $message, "No matches found." );
		}
	}
	else
	{
		# retrieve by id
		my $sth = $dbh->prepare( $Queries->{'select_exact'} );
			  $sth->execute( "$pattern_or_id" );
		my ($id,$quote) = $sth->fetchrow_array();

		unless( defined($quote) )
		{
			return $self->respond( $message, "Quote not found." );
		}

		return $self->respond( $message, "$quote (id: $id)" );
	}
}


sub add_quote
{
	my ($self,$message) = @_;
	my ($quote) = $message->message() =~ m/\+quote\s+(.+?)$/;

	unless( defined($quote) ) {
		return $self->respond( $message, "..." );
	}

	my $id;
	my $max = (reverse sort { $a <=> $b } keys %IDS)[0];
	foreach my $x ( 1 .. $max ) {
		unless( exists $IDS{$x} )  {
			$id = $x; last;
		}
	}
	$id ||= $max+1;

	my $sth = $dbh->prepare( $Queries->{'insert'} );
		  $sth->execute( $id, $quote );
	$IDS{$id} = 1;

	return $self->respond( $message, "Quote added. (id: $id)" );
}


sub del_quote
{
	my ($self,$message) = @_;
	my ($id_to_del) = $message->message() =~ m/\-quote\s+(\d+)$/;

	unless( defined($id_to_del) )
	{
		return $self->respond( $message, "..." );
	}

	if( exists $IDS{$id_to_del} )
	{
		my $sth = $dbh->prepare( $Queries->{'delete'} );
			  $sth->execute( $id_to_del );
		delete $IDS{$id_to_del};
		return $self->respond( $message, "Deleted." );
	}
	else
	{
		return $self->respond( $message, "Quote not found." );
	}
}


sub cnt_quote
{
	my ($self,$message) = @_;

	my $count = (keys %IDS);
	my $are = $count != 1 ? 'are' : 'is';
	my $s   = $count != 1 ? 's'   : '';

	return $self->respond( $message, 
		"There $are currently $count quote$s." );
}


1;


