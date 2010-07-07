package PipSqueek::Plugin::BMI;
use base qw(PipSqueek::Plugin);

sub plugin_initialize {
    my $self = shift;

    $self->plugin_handlers(
        [
            'multi_bmi',
        ]
    );
}

sub multi_bmi {
    my ( $self, $message ) = @_;
    my ( $height, $weight ) = split /\s+/, $message->command_input();

    # bmi = (weight / height^2) * 703

    if ( !$height || !$weight ) {
        return $self->respond(
            $message,
            "Usage: !bmi <height (in)> <weight (lb)>"
        );
    }

    my $bmi = ( $weight / ( $height * $height ) ) * 703;
    $bmi = sprintf "%0.2f", $bmi;

    if ( $bmi < 18.5 ) {
        return $self->respond( $message, "BMI: $bmi - Underweight" );
    } elsif ( $bmi < 25 ) {
        return $self->respond( $message, "BMI: $bmi - Normal" );
    } elsif ( $bmi < 30 ) {
        return $self->respond( $message, "BMI: $bmi - Overweight" );
    } else {
        return $self->respond( $message, "BMI: $bmi - Fatty" );
    }
}


1;


__END__

