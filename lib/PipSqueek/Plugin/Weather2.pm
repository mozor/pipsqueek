package PipSqueek::Plugin::Weather2;
use base qw(PipSqueek::Plugin);

use URI::URL;
use LWP::UserAgent;

sub plugin_initialize
{
  my $self = shift;

  $self->plugin_handlers({
      'multi_weather2'    => 'weather2',
  });
}

sub weather2
{
  my ($self, $message) = @_;
  my $cmd = $message->command();

  my $input = $message->command_input();
  my $url = "http://www.wunderground.com/cgi-bin/findweather/getForecast?query=" . $input;

  $url = URI::URL->new($url);

  my $browser  = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-GB; rv:1.7.5) Gecko/20041110 Firefox/1.0');
  my $response = $browser->get($url);

  unless($response->is_success() && $response->content_type() eq 'text/html')
  {
      return $self->respond($message, "HTTP Error or invalid content type");
  }

  my $results = $response->content();
  $results =~ s/[\n\r]*//g;

  my ($city, $region) = $results =~ /<h1>([^,]+), ([^<]+) <\/h1>/gis;
  my ($temp, $unit) = $results =~ /<nobr><b>(-?\d+)<\/b>&nbsp;&#176;([FC])<\/nobr>/gis;
  my ($temp2,$unit2) = $unit eq 'C' ? ((9*$temp)/5+32,'F') : ((($temp-32)/9)*5,'C');
  my ($weather) = $results =~ /$<div id="b" style="font-size: 14px;">([^<]+)<\/div>/gis;

  $temp2 = sprintf("%0.1f",$temp2);
 
  if(length($city) > 1) {
    $output = "$city, $region" . ": $temp°$unit / $temp2°$unit2, $weather";
  } else {
    $output = "Couldn't find where you were looking for, sorry.";
  }

  return $self->respond($message, $output);
}


1;

__END__
