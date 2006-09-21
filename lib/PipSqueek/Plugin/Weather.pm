package PipSqueek::Plugin::Weather;
use base qw(PipSqueek::Plugin);

use URI::URL;
use LWP::UserAgent;

sub plugin_initialize
{
    my $self = shift;
    
    $self->plugin_handlers({
      'multi_weather'    => 'weather',
      'multi_temp' => 'weather',
    });
}

sub weather
{
    my ($self, $message) = @_;
    my $cmd = $message->command();
    my $url = 'http://www.w3.weather.com/weather/local/ZIP';
    
    my $input = $message->command_input();
    
    if($input) {
        if($input !~ m/^\d{5}$/) {
            return $self->respond($message,
                    "You must enter a US ZIP code. Try !help weather");
        }
        $url =~ s/ZIP/$input/g;
    }

	my $browser  = LWP::UserAgent->new('agent' => 'Mozilla/5.0');
	my $response = $browser->get($url);

	unless($response->is_success() && $response->content_type() eq 'text/html')
	{
		$self->respond($message, 
			"HTTP Error or invalid content type");
		return;
	}

	my $results = $response->content();
       $results =~ s/[\n\r]*//g;

    my ($town, $state) = $results =~ /Local Forecast for ([^,]+), ([A-Z]{2})/gis;
    my ($temp) = $results =~ /<TD VALIGN=MIDDLE ALIGN=CENTER CLASS=obsInfo2 WIDTH=50%><B CLASS=obsTempTextA>(\d+)&deg;F<\/B><\/TD><\/TR>/gis;
    my ($weather) = $results =~ /<TR><TD VALIGN=TOP ALIGN=CENTER CLASS=obsInfo2><B CLASS=obsTextA>(\w+)<\/B><\/TD>/gis;

    my $ouput;

    if(length($town) > 1) {
        $output = "$town, $state" . ": $temp" . "F, $weather"; 
    } else {
        $output = "That place doesn't exist.";
    }

    return $self->respond($message, $output);
}


1;


__END__
