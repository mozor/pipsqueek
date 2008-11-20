package PipSqueek::Plugin::Wunderground;
use base qw(PipSqueek::Plugin);

use utf8;
use Weather::Underground;

sub plugin_initialize
{
  my $self = shift;

  $self->plugin_handlers({
      'multi_wunderground'    => 'wunderground',
  });
}

sub wunderground
{
  my ($self, $message) = @_;
  my $cmd = $message->command();

  my $input = $message->command_input();
 
 
 my $weather = Weather::Underground->new( place => "$input", debug => 0,);

        my $gweather = $weather->get_weather();

        my $tc = $gweather->[0]->{temperature_celsius};
        my $tf = $gweather->[0]->{temperature_fahrenheit};
        my $cond = $gweather->[0]->{conditions};
        my $city = $gweather->[0]->{place};        
 
 
        return $self->respond( $message, "Sorry can't find what you're looking for." ) unless defined $city;
        return $self->respond( $message, "[$input]: $tf°F / $tc°C, $cond" );

}


1;

__END__

