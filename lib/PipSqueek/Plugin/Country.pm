package PipSqueek::Plugin::Country;
use base qw(PipSqueek::Plugin);

use Geo::IP::PurePerl;

# Your GeoIP db should be here.
my $geoip = '/usr/local/pipsqueek/GeoIP.dat';

sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'multi_country',
    ]);
}

sub multi_country
{
    my ($self,$message) = @_;
    my $input = $message->command_input();
        $input =~ s/\s+$//; 
        my $gi = Geo::IP::PurePerl->new( $geoip );  
        # It's ugly, but it works for IP Addresses. Not host names.
        my $country = $gi->country_name_by_addr($input);
    return $self->respond( $message, "Country: $country" );
}


1;


__END__

