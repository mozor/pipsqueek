package PipSqueek::Plugin::Weather;
use base qw(PipSqueek::Plugin);

use URI::URL;
use LWP::UserAgent;

sub plugin_initialize
{
  my $self = shift;

  $self->plugin_handlers({
      'multi_weather'    => 'weather',
  });
}

sub weather
{
  my ($self, $message) = @_;
  my $cmd = $message->command();
  my $config = $self->config();
  my $url;

  my $input = $message->command_input();

  if($input =~ m/\d{5}/) {
    $url = 'http://www.weather.com/weather/local/' . $input;
  } else {
    $url = 'http://www.weather.com/search/enhanced?where=' . $input;
    $url = URI::URL->new($url);

    my $browser  = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-GB; rv:1.7.5) Gecko/20041110 Firefox/1.0');
    $browser->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
    my $response = $browser->get($url);

    unless($response->is_success() && $response->content_type() eq 'text/html') {
      return $self->respond($message, "HTTP Error or invalid content type");
    }

    my $results = $response->content();
    $results =~ s/[\n\r]*//g;

    ($url) = $results =~ m/<B>1.(?:<\/B> | )<A HREF="([^\?]+\?)/gis;
    $url = "http://www.weather.com" . $url;
  }

  $url = URI::URL->new($url);

    my $browser  = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-GB; rv:1.7.5) Gecko/20041110 Firefox/1.0');
    $browser->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());
    my $response = $browser->get($url);

    unless($response->is_success() && $response->content_type() eq 'text/html')
    {
        return $self->respond($message, "HTTP Error or invalid content type");
    }

    my $results = $response->content();
  $results =~ s/[\n\r]*//g;

  my ($city, $region) = $results =~ /Right now for<\/B><BR>([^,]+), ([^<]+)</gis;
  my ($weather) = $results =~ /WIDTH=52 HEIGHT=52 BORDER=0 ALT=><BR><B CLASS=obsTextA>([^<]+)<\/B><\/TD>/gis;
  my ($temp, $unit) = $results =~ /<B CLASS=obsTempTextA>(-?\d+)&deg;([CF])<\/B>/gis;

  my ($temp2,$unit2) = $unit eq 'C' ? ((9*$temp)/5+32,'F') : ((($temp-32)/9)*5,'C');

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
