package PipSqueek::Plugin::DateTime;
use base qw(PipSqueek::Plugin);

use Date::Format;

sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'multi_date',
        'multi_time',
        'multi_dtime',
        'multi_stime',
    ]);
}


sub multi_date
{
    my ($self,$message,$format) = @_;
    my ($timestamp, $timezone) = (time, 'GMT');

    $format ||= "%A, %B %d, %Y";

    my @args = split /\s+/, $message->command_input();

    if (@args == 1) {
        if ($args[0] =~ /^\d+$/) {
            $timestamp = shift @args;
        }
        else {
            $timezone = shift @args;
        }
    }
    elsif (@args == 2) {
        if ($args[0] =~ /^\d+$/) {
            ($timestamp, $timezone) = @args;
        }
        elsif ($args[1] =~ /^\d+$/) {
            ($timezone, $timestamp) = @args;
        }
        else {
            return $self->respond( $message, "Use !help date" );
        }
    }

    $timestamp =~ s/^\s+|\s+$//g;
    $timezone  =~ s/^\s+|\s+$//g;

    my @time = localtime($timestamp);
    $self->respond( $message, strftime($format, @time, $timezone) );
}


sub multi_time
{
    (shift)->multi_date(@_, "%T %Z");
}


sub multi_dtime
{
    (shift)->multi_date(@_, "%A, %B %d, %Y %T %Z");
}


sub multi_stime
{
    (shift)->respond( shift, time() );
}


1;


__END__
