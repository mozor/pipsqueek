package PipSqueek::Plugin::DateTime;
use base qw(PipSqueek::Plugin);

use Date::Format;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_date',
		'multi_time',
		'multi_stime',
	]);
}


sub multi_date
{
	my ($self,$message) = @_;
	my $tz = $message->command_input() || 'GMT';
	my @time = localtime(time);
	$self->respond( $message, strftime("%A %B the %d, %Y", @time, $tz) );
}


sub multi_time
{
	my ($self,$message) = @_;
	my $tz = $message->command_input() || 'GMT';
	my @time = localtime(time);
	$self->respond( $message, strftime("%T $tz", @time, $tz) );
}


sub multi_stime
{
	(shift)->respond( shift, time() );
}


1;


__END__
