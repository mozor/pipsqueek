package l8nite::mysql;

require 5.005_62;
use strict;
use vars qw($VERSION);

use DBI;

our $VERSION = '0.01';


##################################################
# Ye Olde Contructor Methode. You know the drill.
# Takes absolutely no args whatsoever.
sub new {
    my $proto = shift;

    my $self = {
	        'dbh'	=> "",
		'query'	=> ""
	    };

    bless $self, $proto;
  
    return $self;
}

##################################################
# Connect to the database
sub connectDB()
{
	my ($self,$database_name, $database_user, $user_password ) = @_;
	$self->{dbh} = DBI->connect("DBI:mysql:$database_name","$database_user","$user_password", { LongReadLen => 102400 }) or die print "mysql.pm: Error connecting database\n";
}


##################################################
# Generates an SQL query to the	database.
sub doQuery
{
	my ($self) = @_;
	$self->{query} = $self->{dbh}->prepare("$_[1]") || die print "mysql.pm: Error preparing statement\n";
	$self->{query}->execute || die print "mysql.pm: Error executing command\n\t$_[1]\n\t$DBI::errstr\n";
}


##################################################
# Executes the query, returns the first row of results and cleans up
sub oneShot
{
	my ($self) = @_;
	$self->{query} = $self->{dbh}->prepare("$_[1]") || die print "mysql.pm: Error preparing statement\n";
	$self->{query}->execute || die print "mysql.pm: Error executing command\n\t$_[1]\n\t$DBI::errstr\n";
	my (@results) = $self->{query}->fetchrow_array();
	$self->{query}->finish();
	$self->{query}="";
	return @results;
}


##################################################
# Executes the query, and cleans up (open/close)Query
sub ocQuery
{
	my ($self) = @_;
	$self->{query} = $self->{dbh}->prepare("$_[1]") || die print "mysql.pm: Error preparing statement\n";
	$self->{query}->execute || die print "mysql.pm: Error executing command\n\t$_[1]\n\t$DBI::errstr\n";
	$self->{query}->finish();
	$self->{query}="";
}


##################################################
# Fetch the next row of results
sub getResults
{
	my ($self) = @_;
	return $self->{query}->fetchrow_array();
}


##################################################
# Releases the query results
sub finishQuery
{
	my ($self) = @_;
	$self->{query}->finish() unless $self->{query} eq "";
	$self->{query}="";
}


##################################################
# Releases the database connection 
sub disconnectDB
{
	my ($self) = @_;
	$self->{dbh}->disconnect unless $self->{dbh} eq "";
	$self->{dbh}="";
}


1;
__END__

=head1 NAME

l8nite::mysql - Perl extension for encapsulating mysql calls into an easy to use format

=head1 SYNOPSIS

  use l8nite::mysql;

  my ($sql_conn) = new l8nite::mysql;
  $sql_conn->connectDB( 'pipqueek', 'l8nite', 'password' );
  $sql_conn->doQuery( qq~SELECT * FROM table~ );
  my (@results) = $sql_conn->getResults();
  $sql_conn->finishQuery();
  $sql_conn->disconnectDB();

=head1 DESCRIPTION

Well, if you ask nicely I might fill this in =)

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

Shaun Guth aka "l8nite" - perlhacker@l8nite.net

=head1 SEE ALSO

perl(1).

=cut
