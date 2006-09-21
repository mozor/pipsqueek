package PipSqueek::Plugin::Birthdays;
use base qw(PipSqueek::Plugin);
use strict;

use Date::Parse;
use POSIX qw(strftime);


sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers({
		'public_+birthday'  => 'public_add_birthday',
		'public_-birthday'  => 'public_del_birthday',
		'public_#birthdays' => 'public_cnt_birthdays',
		'multi_birthdays'   => 'multi_birthdays',
		'multi_birthday'    => 'multi_birthday',
	});

	my $schema = [
		[ 'id',		'INTEGER PRIMARY KEY' ],
		[ 'day',	'INT NOT NULL' ],
		[ 'month',	'INT NOT NULL' ],
		[ 'year',	'INT NOT NULL' ],
		[ 'name',	'VARCHAR NOT NULL' ],
	];

	$self->dbi()->install_schema( 'birthdays', $schema );
}



sub public_add_birthday
{
	my ($self,$message) = @_;
	my ($name,@date) = split(/\s+/,$message->command_input());
	my $date = join(' ',@date);

	my $time = str2time($date);

	unless( $name && $date )
	{
		$self->respond( $message, "Use !help +birthday" );
		return;
	}

	unless( $time )
	{
		$self->respond( $message, "Invalid date" );
		return;
	}
	
	my $bday = $self->dbi()->select_record( 'birthdays',
			{ 'LOWER(name)' => lc($name) } );

	if( $bday )
	{
		$self->respond($message, "I already know about that birthday");
		return;
	}

	my ($day,$month,$year) = (gmtime($time))[3,4,5];
	$year+=1900;

	my $bday = $self->dbi()->create_record( 'birthdays',
			  { 'name' => $name,
			    'day' => $day, 
			    'month' => $month, 
			    'year' => $year }
		   );

	$self->respond( $message, "Birthday recorded (id: $bday->{'id'})" );

	return;
}


sub public_del_birthday
{
	my ($self,$message) = @_;
	my $id = $message->command_input();

	if( !defined($id) || $id eq "" )
	{
		$self->respond( $message, "Invalid id" );
		return;
	}
	
	my $bday = undef;

	if( $id =~ /[^\d]/ ) 
	{
		$bday = $self->dbi()->select_record( 'birthdays', 
				{ 'name' => $id } );
	}
	else
	{
		$bday = $self->dbi()->select_record( 'birthdays', 
				{ 'id' => $id } );
	}

	unless( $bday )
	{
		$self->respond($message, "I don't have any record of that id");
		return;
	}

	$self->dbi()->delete_record( 'birthdays', $bday );

	$self->respond( $message, "Deleted." );

	return;
}


sub public_cnt_birthdays
{
	my ($self,$message) = @_;

	my ($num) = $self->dbi()->dbh()->selectrow_array( 
			'SELECT COUNT(id) FROM birthdays' );
	
	my $s = $num == 1 ? '' : 's';
	$self->respond( $message, "I know of $num birthday$s total" );

	return;
}


sub multi_birthdays
{
	my ($self,$message) = @_;

	my $months =
		{'january' => 0, 'february' => 1, 'march' => 2,
		 'april' => 3, 'may' => 4, 'june' => 5, 'july' => 6,
		 'august' => 7, 'september' => 8, 'october' => 9,
		 'november' => 10, 'december' => 11};


	my $month = lc($message->command_input());
	   $month = exists $months->{$month}
			? $months->{$month}
			: (gmtime(time))[4];


	my $sql = 'SELECT name,day,month,year FROM birthdays ' .
		  'WHERE month = ? ORDER BY day ASC';
	my $sth = $self->dbi()->dbh()->prepare( $sql );
	   $sth->execute( $month );

	my @bdays = @{$sth->fetchall_arrayref()};


	my $this_month = $month == (gmtime(time))[4]
				? 'this month'
				: strftime("in %B",0,0,0,0,$month+1,0);

	unless( @bdays )
	{
		$self->respond( $message, "No birthdays $this_month" );
		return;
	}

	my $num = @bdays;
	my $s = $num == 1 ? '' : 's';
	my $are = $num == 1 ? 'is' : 'are';
	my $output = "There $are $num birthday$s $this_month:  ";

	@bdays = map { 
		my ($n,$d,$m,$y) = @$_;
		$d = strftime( "%B %d", 0, 0, 0, $d, $m, 0 );
		"$n ($d)";
	} @bdays;

	local $" = ',  ';
	$output .= "@bdays";

	$self->respond($message, $output);
	return;
}


sub multi_birthday
{
	my ($self,$message) = @_;
	my $name = $message->command_input();

	unless( $name )
	{
		$self->respond( $message, "You must specify a user" );
		return;
	}

	chomp $name;
	my $bday = $self->dbi()->select_record( 'birthdays',
			{ 'LOWER(name)' => lc($name) } );

	unless( $bday )
	{
		$self->respond( $message, "Doesn't look like I know yet..." );
		return;
	}

	$name = $bday->{'name'};

	my ($bd,$bm,$by) = ($bday->{'day'},$bday->{'month'},$bday->{'year'});
	my ($td,$tm,$ty) = (gmtime(time))[3,4,5];
	$ty += 1900;

	my $age = $ty - $by;
	my $num = $self->_end( $age );
	my $id  = $bday->{'id'};

	my $bdnum = $self->_end( $bd );
	
	my $date = strftime( "%A %B the $bdnum, %Y",0,0,0,$bd,$bm,$ty-1900 );

	# is their birthday today?
	if( $bd == $td && $bm == $tm )
	{
		$self->respond( $message, 
			"$name\'s $num birthday is today ($date)! (id: $id)" ); return;
	}

	# was their birthday before today?
	if( $bm < $tm || ( $bm == $tm && $bd < $td ) )
	{
		$self->respond( $message, 
			"$name\'s $num birthday was on $date. (id: $id)" );
		return;
	}
	else
	{
		$self->respond( $message,
			"$name\'s $num birthday is on $date. (id: $id)" );
		return;
	}

	return;
}


sub _end
{
	my ($self,$num) = @_;
	my $end = $num == 11 || $num == 12 || $num == 13
		? 'th'
		: $num =~ /1$/
		? 'st' 
		: $num =~ /2$/ 
		? 'nd'
		: $num =~ /3$/ 
		? 'rd'
		: 'th';

	return "$num$end";
}


1;


__END__
