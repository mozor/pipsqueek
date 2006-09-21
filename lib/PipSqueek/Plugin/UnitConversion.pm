package PipSqueek::Plugin::UnitConversion;
use base qw(PipSqueek::Plugin);

use Math::Units qw(convert);

my $autounit = {};

sub plugin_initialize
{
  my $self = shift;

  foreach my $line (<DATA>) {
    chomp($line);
    my ($key, $val) = split(/ /, $line, 2);
    $autounit->{$key} = $val;
  }

  $self->plugin_handlers([
    'irc_public',
    'multi_convert' 
  ]);
}


sub irc_public {
  my ($self, $message) = @_;

  if($message->message() =~ m/^.*\b(\d+)\s*?(\S+)/) {
    my $session_heap = $self->client()->get_heap();

    if($autounit->{$2}) {
      $session_heap->{'last_autoconvert_amount'} = $1;
      $session_heap->{'last_autoconvert_unit'} = $2;

      #$self->respond($message, "Got a new match: '" . $session_heap->{'last_autoconvert_unit'} . "'");
    }
  }
}


sub multi_convert
{
	my ($self,$message) = @_;
  my $session_heap = $self->client()->get_heap();
  my ($amount,$from,$to);

  # Users can use '#' to insert values from normal chatter
  # e.g. I ate 6 pounds of chocolate
  # would match '6' and 'pounds' and convert to kg with  !convert #
  # You can also specify a unit to convert to if you don't want the default.
  if($message->command_input() =~ m/^\#\s*([\w\^]+)?/) {
    $amount = $session_heap->{'last_autoconvert_amount'} || 1;
    $from   = $session_heap->{'last_autoconvert_unit'};
    if($1) {
      $to = $1;
    } else {
      $to     = $autounit->{$from};
    }

    #$self->respond($message, "amt: '$amount' | from: '$from' | to: '$to'");
  } else {
  	$message->command_input() =~ m/^
	  	([\$[+-]?[\d\.]+|_|\#)?\s*
		  (?:from\s+)?
  		([\w\^]+)\s+
	  	(?:to\s+)?
		  ([\w\^]+)
  		/ix;

	  ($amount,$from,$to) = ($1||1,$2,$3);
  }

	# users can use '_' to insert values from previous money or math calls
	if ( $amount eq '_' )
	{
		$amount = $session_heap->{'last_math_result'} || 1;
	}

	unless( defined($amount) && $from && $to )
	{
		$self->respond( $message, "See !help convert" );
		return;
	}

	eval {
		my $final = convert( $amount, $from, $to );
		$session_heap->{'last_math_result'} = $final;
		$self->respond( $message, "$amount $from = $final $to" );
	};

	if( $@ )
	{
		$self->respond( $message, "Error in conversion" );
	}
}


1;


__DATA__
in cm
inches cm
inch cm
cm in
centimetres in
centimetre in
centimeters in
centimeter in
mm in
millimeter in
millimeters in
millimetres in
millimetre in
ft m
feet m
foot m
yd m
yards m
yard m
m ft
meters ft
metres ft
meter ft
metre ft
mi km
mile km
miles km
km mi
kilometre mi
kilometer mi
kilometres mi
kilometers mi
lb kg
lbs kg
pound kg
pounds kg
kg lb
kilograms lb
kilogram lb
g oz
grams oz
gram oz
oz g
ounce g
ounces g
mg oz
milligrams oz
milligram oz
F C
fahrenheit C
C F
celsius F
centigrade F
__END__
