package PipSqueek::Plugin::UnitConversion;
use base qw(PipSqueek::Plugin);

use Physics::Unit ':ALL';

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
        local *Foo::carp = sub { $self->respond($message, @_); };
        #\&Foo::croak();
        my $u_from = GetUnit($from);
        my $u_to = GetUnit($to);
        my $c = $u_from->convert($u_to);
        my $final = $amount * $c;
        $session_heap->{'last_math_result'} = $final;
        my $u_from_name = $u_from->name();
        my $u_to_name = $u_to->name();
        $self->respond( $message, "$amount $u_from_name = $final $u_to_name" );
    };

    if( $@ )
    {
        $self->respond( $message, "Error in conversion" );
    }
}


1;


__END__
