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
    $p_bmi = sprintf "%0.2f", $bmi;

    if ( $bmi < 18.5 ) {
        my $gain = sprintf("%0.1f", (18.5 / 703) * ($height * $height));
        return $self->respond( $message, "BMI: $p_bmi - Underweight (Gain $gain pounds to be 'Normal')" );
    } elsif ( $bmi < 25 ) {
        return $self->respond( $message, "BMI: $p_bmi - Normal" );
    } elsif ( $bmi < 30 ) {
        my $lose = (24.9 / 703) * ($height * $height);
        return $self->respond( $message, "BMI: $p_bmi - Overweight (Lose at least $lose pounds to be 'Normal')" );
    } else {
        my $lose = (24.9 / 703) * ($height * $height);
        return $self->respond( $message, "BMI: $p_bmi - Fatty (Lose at least $lose pounds to be 'Normal')" );
    }
}


1;


__END__

