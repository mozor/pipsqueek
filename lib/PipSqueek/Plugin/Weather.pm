package PipSqueek::Plugin::Weather;
use base qw(PipSqueek::Plugin);

sub plugin_initialize {
    my $self = shift;

    $self->plugin_handlers(
        {
            'multi_w'        => 'weather',
            'multi_weather'  => 'weather',
            'multi_weather2' => 'weather',
            'multi_+w'        => 'add_weather',
            'multi_+weather'  => 'add_weather',
            'multi_+weather2' => 'add_weather',

# TODO: this should probably be handled
#            'pipsqueek_mergeuser' => 'pipsqueek_mergeuser',
        }
    );

    # set up our database table
    my $schema = [
        [ 'id',     'INTEGER PRIMARY KEY' ],
        [ 'userid',    'INT NOT NULL' ],
        [ 'home_loc', 'VARCHAR'],
        [ 'last_loc', 'VARCHAR'],
    ];

    $self->dbi()->install_schema( 'weather', $schema );
}

sub add_weather {
    my $self = shift;
    $self->weather(@_, 1);
}

sub weather {
    my ( $self, $message, $store_as_home_loc ) = @_;

    my $weather_by_username = 0;
    my $db_weather = $self->search_weather($message);

    my $input = $message->command_input();
       $input =~ s/\s+$//;
       $input =~ s/^\s+//;

    my $location;

    # if they didn't specify any input, try to use their last_loc
    if (!$input || $input eq "") {
        $location = $db_weather->{'last_loc'};
        unless ($location) {
            $location = $db_weather->{'home_loc'};

            unless ($location) {
                return $self->respond($message, "Try !w <location>, or !+w <home location> first");
            }
        }
    }
    # otherwise, see if it's a valid username and that user has a home_loc
    else {
        my $user  = $self->search_user($input);
        if ($user) {
            $weather_by_username = 1;
            $db_weather = $self->dbi()->select_record( 'weather',
                { 'userid' => $user->{'id'} }
            );

            if ($db_weather) {
                $location = $db_weather->{'home_loc'};
            }
        }
        # not a valid user, let's see if they want us to store this
        else {
            $location = $input;
        }
    }

    my ($response, $success) = $self->get_weather($location);
    
    $self->respond( $message, $response );

    if ($success) {
        unless ($weather_by_username) {
            $db_weather->{'last_loc'} = $location;
        }

        if ($store_as_home_loc) {
            $self->respond( $message, "Storing your home location as: $location");
            $db_weather->{'home_loc'} = $location;
        }
    } else {
        if ($store_as_home_loc) {
            $self->respond( $message, "Location was not stored" );
        }
    }
    
    if ($db_weather) {
        $self->dbi()->update_record( 'weather', $db_weather );
    }
}


# some helper functions for the database
sub search_weather
{
    my ($self,$message) = @_;
    my $user = $self->search_or_create_user($message);

    my $weather = $self->dbi()->select_record( 'weather',
            { 'userid' => $user->{'id'} }
            );

    unless( $weather )
    {
        $weather =
        $self->dbi()->create_record( 'weather',
            { 'userid' => $user->{'id'} }
        );
    }

    return $weather;
}


sub get_weather
{
    my ($self, $input) = @_;

    my $uaw = LWP::UserAgent->new;
    $uaw->timeout(5);
    $uaw->proxy( [ 'http', 'ftp' ], $self->config()->plugin_proxy() )
      if ( $self->config()->plugin_proxy() );

    my $gw = $uaw->get( 'http://www.google.com/ig/api?weather=' . "$input" );

    unless ($gw->is_success()) {
        return "Error reaching weather service";
    }

    my $content = $gw->content;

    my ($city)       = $content =~ /city data=\"(.+?)\"\//gis;
    my ($tempf)      = $content =~ /temp_f data=\"(.+?)\"/gis;
    my ($tempc)      = $content =~ /temp_c data=\"(.+?)\"/gis;
    my ($conditions) = $content =~ /condition data=\"(.+?)\"\//gis;
    my ($humidity)   = $content =~ /humidity data=\"(.+?)\"\//gis;
    my ($wind)       = $content =~ /wind_condition data=\"(.+?)\"\//gis;

    unless ($city) {
        return "Sorry, I can't find what you're looking for.";
    }

    return ("$city: $tempf\x{B0}F / $tempc\x{B0}C, $conditions - $humidity - $wind", 1);
}


1;

__END__




