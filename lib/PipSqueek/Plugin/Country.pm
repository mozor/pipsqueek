package PipSqueek::Plugin::Country;
use base qw(PipSqueek::Plugin);
use IP::Country::MaxMind;

sub plugin_initialize
{
    my $self = shift;
    $self->plugin_handlers(
        {
         'multi_ipv4' => 'ipv4',

        }
    );

}

sub ipv4
{
    my ($self, $message) = @_;

    my $input   = $message->command_input();
    my $MMData  = '/tmp/GeoIP.dat';
    my $gi      = IP::Country::MaxMind->new($MMData);
    my $country = $gi->inet_atocc("$input");

    unless ($country)
    {
        return $self->respond($message, "ERROR \"No results.\"");
    }

    return $self->respond($message, "$input: $country ");

}

1;
