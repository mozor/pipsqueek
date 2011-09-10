package PipSqueek::Plugin::NickServ;
use base qw(PipSqueek::Plugin);
use strict;


sub config_initialize
{
    my $self = shift;

    $self->plugin_configuration({
        'nickserv_identify' => 0,
        'nickserv_password' => '',
        'nickserv_identify_format' => 'IDENTIFY $password',
        'nickserv_register' => 0,
        'nickserv_register_email' => '',
        'nickserv_register_format' => 'REGISTER $password $email',
        'nickserv_services_name' => 'NickServ',
    });
}


sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'irc_001',
    ]);
}


sub irc_001
{
    my ($self,$message) = @_;
    my $config = $self->config();

    my $nickserv = $config->nickserv_services_name();

    my $identify = $config->nickserv_identify();
    my $password = $config->nickserv_password();
    my $idformat = $config->nickserv_identify_format();

    my $register  = $config->nickserv_register();
    my $regemail  = $config->nickserv_register_email();
    my $regformat = $config->nickserv_register_format();

    if( $register )
    {
        $regformat =~ s/\$password/$password/gi;
        $regformat =~ s/\$email/$regemail/gi;

        $self->client()->privmsg( $nickserv, $regformat );
    }

    if( $identify )
    {
        $idformat =~ s/\$password/$password/gi;
    
        $self->client()->privmsg( $nickserv, $idformat );
    }
}


1;


__END__
