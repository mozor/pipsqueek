package PipSqueek::Plugin::GoogleWeather;
use base qw(PipSqueek::Plugin);

sub plugin_initialize {
    my $self = shift;

   $self->plugin_handlers({
		'multi_w'      => 'weather',
                'multi_weather'      => 'weather',
		'multi_weather2'	=> 'weather',


	});
}
sub weather {
		my ( $self, $message ) = @_;
		my $input = $message->command_input();
		$input =~ s/\s+$//;

my $uaw = LWP::UserAgent->new;
   $uaw->timeout(15);
   $uaw->proxy(['http','ftp'], $self->config()->plugin_proxy()) if ($self->config()->plugin_proxy());

my $gw = $uaw->get('http://www.google.com/ig/api?weather=' . "$input");
my $content = $gw->content;

		my ($city) = $content =~ /city data=\"(.+?)\"\//gis;
		my ($tempf) = $content =~ /temp_f data=\"(.+?)\"/gis;
		my ($tempc) = $content =~ /temp_c data=\"(.+?)\"/gis;
		my ($conditions) = $content =~ /condition data=\"(.+?)\"\//gis;
		my ($humidity) = $content =~ /humidity data=\"(.+?)\"\//gis;
		my ($wind) = $content =~ /wind_condition data=\"(.+?)\"\//gis;

		return $self->respond( $message, "Sorry, I can't find what you're looking for." ) unless defined $city;
		return $self->respond( $message, "$city: $tempf°F / $tempc°C, $conditions - $humidity - $wind" );

};


1;

__END__




