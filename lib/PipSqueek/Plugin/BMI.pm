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
        $gain = $gain - $weight;
        return $self->respond( $message, "BMI: $p_bmi - Underweight ($gain below Normal)");
    } elsif ( $bmi < 25 ) {
        return $self->respond( $message, "BMI: $p_bmi - Normal" );
    } elsif ( $bmi < 30 ) {
        my $lose = sprintf("%0.1f", (24.9 / 703) * ($height * $height));
        $lose = $weight - $lose;
        return $self->respond( $message, "BMI: $p_bmi - Overweight ($lose above Normal)");
    } else {
        my $lose = sprintf("%0.1f", (24.9 / 703) * ($height * $height));
        $lose = $weight - $lose;
        return $self->respond( $message, "BMI: $p_bmi - Obese ($lose above Normal)");
    }
}


1;


__END__

