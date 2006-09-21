package PipSqueek::DBI;
use base 'Class::Accessor::Fast';
use strict;

use DBI;

sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = bless( {}, $class );

	$self->mk_accessors( 'dbh', 'schemas' );

	$self->schemas({});

	$self->connect_database(@_) if @_;

	return $self;
}

sub connect_database
{
	my $self = shift;

	if( ref($_[0]) =~ /^DBI/ )
	{
		$self->dbh(shift);
	}
	else
	{
		$self->dbh( DBI->connect(shift, @_) );
	}
}

sub install_schema
{
	my ($self,$table,$schema) = @_;

	return 0 if $self->check_table_exists($table);

	my @sfill = map { "@$_" } @$schema;

	local $" = ',';

	my $sql = "CREATE TABLE $table ( @sfill )";
	$self->dbh()->do( $sql );

	
	my $data = $self->schemas();
	$data->{$table} = $schema;
	$self->schemas($data);

	return 1;
}

sub check_table_exists
{
	my ($self,$table) = @_;

	my $sql = 'SELECT tbl_name FROM sqlite_master ' .
		  'WHERE type="table" AND tbl_name=?';
	my $sth = $self->dbh()->prepare( $sql );
	   $sth->execute($table);

	my ($table) = $sth->fetchrow_array();
	
	return $table;
}


#-- begin sql-related functions --#
sub create_record
{
	my ($self,$table,$data) = @_;
	my $dbh = $self->dbh();

	my @fields = keys %$data;
	my @values = map { $data->{$_} } @fields;
	my @placeh = map { '?' } @fields;

	local $" = ',';
	my $sql = "INSERT INTO $table (@fields) VALUES(@placeh)";
	my $sth = $dbh->prepare( $sql );
	   $sth->execute( @values );
#print "$sql\n[@values]\n";

	my $rid  = ($dbh->selectrow_array( "SELECT LAST_INSERT_ROWID()" ))[0];

	return $self->select_record( $table, { 
			'id' => $rid 
		} );
}


sub select_record
{
	my ($self,$table,$data,$custom,@values) = @_;
	my $dbh = $self->dbh();

	if( defined($custom) && $custom ne "" )
	{
		my $sth = $self->dbh()->prepare( $custom );
		   $sth->execute(@values);

		return $sth->fetchrow_hashref( 'NAME_lc' );
	}

	my @fields = keys %$data;

	my @placeh = map { 
			my $tmp = $data->{$_};
			my $cmp = ref($tmp) ? $tmp->[0] : '=';

			"$_ $cmp ?";
		     } @fields;

	my @values = map {
			my $tmp = $data->{$_};
			$_ = ref($tmp) ? $tmp->[1] : $tmp;
		     } @fields;

	local $" = ' AND ';
	my $sql = "SELECT * FROM $table WHERE @placeh";
	my $sth = $dbh->prepare( $sql );
	   $sth->execute(@values);

#print "$sql\n[@values]\n";

	return wantarray 
		? @{$sth->fetchall_arrayref()} 
		: $sth->fetchrow_hashref( 'NAME_lc' );
}


sub update_record
{
	my ($self,$table,$record,$data) = @_;
	my $dbh = $self->dbh();

	if( defined($record) && !defined($data) ) 
	{
		$data = $record;
	}

	if( defined($record) && ref($record) ne 'HASH' )
	{
		$record = { 'id' => $record };
	}

	my @fields = keys %$data;
	my @placeh = map { "$_=?" } @fields;
	my @values = map { $data->{$_} } @fields;

	local $"=',';
	my $sql = "UPDATE $table SET @placeh";

	if( defined($record) )
	{
		$sql .= " WHERE id=?";
		my $sth = $dbh->prepare( $sql );
		   $sth->execute( @values, $record->{'id'} );
#print "$sql\n[@values,$record->{'id'}]\n";
	}
	else
	{
#print "$sql\n[@values]\n";
		my $sth = $dbh->prepare( $sql );
		   $sth->execute( @values );
	}
}


sub delete_record
{
	my ($self,$table,$record) = @_;
	my $dbh = $self->dbh();

	my $sql = "DELETE FROM $table WHERE id=?";
	my $sth = $dbh->prepare( $sql );
	   $sth->execute( $record->{'id'} );
}


1;


__END__
