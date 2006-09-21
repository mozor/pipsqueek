package PipSqueek::Plugins::Units;
use base qw(PipSqueek::Plugin);

use Math::Units qw(convert);

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers(
		'multi_convert'  => 'unit_conversion',
	);
}

sub plugin_teardown { }

sub unit_conversion
{
	my ($self,$message) = @_;

	my ($amount,$from,$to) = $message->message() =~ 
		m/convert (?:([\d.,_]+) )?([\w\^]+) ([\w\^]+)/;

	my $Heap = $self->kernel()->get_active_session()->get_heap();

	if( $amount eq '_' )
	{
		$amount = $Heap->{'last_math_result'};
	}
	$amount ||= 1;

	unless( $amount && $from && $to )
	{
		return $self->respond( $message, "Invalid parameters" );
	}

	eval {
		my $final = convert( $amount, $from, $to );
		$Heap->{'last_math_result'} = $final;
		$self->respond( $message, "$amount $from = $final $to" );
	};

	if( $@ )
	{
		$self->respond( $message, "Error in conversion" );
	}
}


1;


