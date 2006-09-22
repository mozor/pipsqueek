package PipSqueek::Plugin::UnitConversion;
use base qw(PipSqueek::Plugin);

use Math::Units qw(convert);

sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'multi_convert' 
    ]);
}


sub multi_convert
{
    my ($self,$message) = @_;

    $message->command_input() =~ m/^
        ([\$[+-]?[\d\.]+|_)?\s*
        (?:from\s+)?
        ([\w\^]+)\s+
        (?:to\s+)?
        ([\w\^]+)
        /ix;

    my ($amount,$from,$to) = ($1||1,$2,$3);

    my $session_heap = $self->client()->get_heap();

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


__END__
