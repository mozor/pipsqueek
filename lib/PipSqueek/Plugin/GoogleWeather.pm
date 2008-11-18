package PipSqueek::Plugin::GoogleWeather;
use base qw(PipSqueek::Plugin);

use Weather::Google;
use utf8;

sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'multi_w',
        'multi_f',        
    ]);
}

sub multi_w
{
    my ($self,$message) = @_;
    my $input = $message->command_input();
            $input =~ s/\s+$//; 
            
         $gw = new Weather::Google;
 

         if ($input eq m/^[0-9]{5}/){ 
                 $gw->zip($input);
         } else {
                 $gw->city($input);
         }

        
                $current = $gw->current; 
                $tc = $current->{temp_c};
                $tf = $current->{temp_f};
                $hum = $gw->humidity;
                $wind = $gw->wind_condition;
                $city = $gw->info('city');
                $cond = $gw->condition;

        return $self->respond( $message, "Sorry can't find what you're looking for." ) unless defined $city;
        return $self->respond( $message, "$city: $tf°F / $tc°C , $cond - $hum - $wind" );

}

sub multi_f
{
    my ($self,$message) = @_;
    my $input = $message->command_input();
            $input =~ s/\s+$//; 
            
         $gw = new Weather::Google;
 

         if ($input eq m/^[0-9]{5}/){ 
                 $gw->zip($input);
         } else {
                 $gw->city($input);
         }

        
                $city = $gw->info('city');
                $today = $gw->forecast_conditions(0);
                $phigh = $today->{high};
                $plow = $today->{low};       
                $pcnd = $today->{condition};       
                $pday = $today->{day_of_week};
                $date = $gw->forecast_information('forecast_date');

                
                         
        return $self->respond( $message, "Sorry can't find what you're looking for." ) unless defined $city;
        return $self->respond( $message, "[$pday] $city: High $phigh°F / Low $plow°F with $pcnd - $date" );

}





1;


__END__


