package PipSqueek::Plugin::SystemUptime;
use base qw(PipSqueek::Plugin);
use strict;

use Data::Dumper;


sub plugin_initialize
{
    my $self = shift;
    $self->plugin_handlers([
        'multi_sysuptime'
    ]);
}


sub multi_sysuptime
{
    my ($self,$message) = @_;

    my $SysUptime = `uptime`;

    return $self->respond( $message, "$SysUptime" );
}


1;


__END__
