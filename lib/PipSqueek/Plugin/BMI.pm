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
    my ( $height, $weight, $metric) = split /\s+/, $message->command_input();

    # bmi = (weight / height^2) * 703

    if ( !$height || !$weight ) {
        return $self->respond(
            $message,
            "Usage: !bmi <height> <weight> [metric]"
        );
    }

    my $bmi = $metric 
        ? ($weight / ($height*$height))
        : ($weight / ($height*$height)) * 703;

    my $wgt = $metric 
        ? ($target_bmi) * ($height * $height)
        : ($target_bmi / 703) * ($height * $height);

    my $diff = $wgt - $weight;

    my $label = 
        $bmi < 18.5 ? 'Underweight' :
        $bmi < 25.0 ? 'Normal' :
        $bmi < 30.0 ? 'Overweight' :
                      'Obese';

    my $justdoit = $label ne 'Normal'
        ? sprintf(" (%0.1f%s %s normal)", $diff, $metric ? 'kg' : 'lb', $diff > 0 ? 'below' : 'above')
        : "";

    my $response = sprintf("BMI: %0.1f - %s%s", $bmi, $label, $justdoit);

    return $self->respond($message, $response);
}


1;


__END__

