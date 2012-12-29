package PipSqueek::Plugin::Weather;
use base qw(PipSqueek::Plugin);
 
use JSON;
use URI::URL;
use LWP::UserAgent;
 
sub plugin_initialize
{
  my $self = shift;
 
  $self->plugin_handlers({
      'multi_weather'    => 'weather',
      'multi_w'          => 'weather',
  });
}
 
sub weather
{
  my ($self, $message) = @_;
  my $cmd = $message->command();
  my $url;
 
  # this could probably be better served pulled from a config. :)
  my $wwkey = 'OH_NO_YOU_DONT_BOYO';
 
  my $input = $message->command_input();
  # quick n nastay url encoding
  $input =~ s/ /%20/g;
  $input =~ s/,/%2C/g;
 
  $url = "http://api.wunderground.com/api/$wwkey/geolookup/conditions/q/$input.json";
  $url = URI::URL->new($url);
 
  my $browser  = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-GB; rv:1.7.5) Gecko/20041110 Firefox/1.0');
  my $response = $browser->get($url);
 
  unless($response->is_success() && $response->content_type() eq 'application/json') {
    return $self->respond($message, "HTTP Error or invalid content type");
  }
 
  my $results = $response->content();
 
  my $decoded_json = decode_json( $results );
 
  my $o_tz    = $decoded_json->{'location'}->{'tz_short'};
  my $o_city  = $decoded_json->{'location'}->{'city'};
  my $o_state = $decoded_json->{'location'}->{'state'};
 
  my $o_t_feels_c = $decoded_json->{'current_observation'}->{'feelslike_c'};
  my $o_t_feels_f = $decoded_json->{'current_observation'}->{'feelslike_f'};
  my $o_t_c       = $decoded_json->{'current_observation'}->{'temp_c'};
  my $o_t_f       = $decoded_json->{'current_observation'}->{'temp_f'};
  my $o_t_rh      = $decoded_json->{'current_observation'}->{'relative_humidity'};
  my $o_t_weather = $decoded_json->{'current_observation'}->{'weather'};
  my $o_t_wind    = $decoded_json->{'current_observation'}->{'wind_string'};
 
  # I thumb my nose and proper error correction
  # Tryin' to catch me codin' dirty ..
 
  if( $o_tz eq '', $o_city eq '', $o_state eq '' ) {
    return $self->respond($message, "GENERIC ERROR MESSAGE OH F-");
  }
 
  my $output = sprintf("It is now %sF in %s, %s. The weather is %s and the wind is %s.\n", $o_t_f, $o_city, $o_state, $o_t_weather, $o_t_wind);
 
  return $self->respond($message, $output);
}
 
 
1;
 
__END__