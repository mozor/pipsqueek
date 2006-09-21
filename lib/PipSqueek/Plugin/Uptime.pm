package PipSqueek::Plugin::Uptime;
use base qw(PipSqueek::Plugin);

use integer;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_uptime'  
	]);
}


sub multi_uptime
{
	my ($self,$message) = @_;
	my $ela = time() - $^T;

	my $day = $ela / 86400; $ela %= 86400;
	my $yea = $day / 365;   $day %= 365;
	my $cen = $yea / 100;   $yea %= 100;
	my $mil = $cen / 10;    $cen %= 10;
	my $hou = $ela / 3600;  $ela %= 3600;
	my $min = $ela / 60;    $ela %= 60;
	my $sec = $ela;

	my @list = ();
	push( @list, "$mil " . &_p('milleni','um','a',  $mil) ) if $mil;
	push( @list, "$cen " . &_p('centur', 'y', 'ies',$cen) ) if $cen;
	push( @list, "$yea " . &_p('year',   '',  's',  $yea) ) if $yea;
	push( @list, "$day " . &_p('day',    '',  's',  $day) ) if $day;
	push( @list, "$hou " . &_p('hour',   '',  's',  $hou) ) if $hou;
	push( @list, "$min " . &_p('minute', '',  's',  $min) ) if $min;
	push( @list, "and" ) if $sec;
	push( @list, "$sec " . &_p('second', '',  's',  $sec) ) if $sec;
	my $output = join(' ', @list );

	return $self->respond( $message, "I have been active for $output" );
}


sub _p
{
	my ($w,$e1,$e2,$t) = @_;

	return $t != 1 ? "$w$e2" : "$w$e1";
}


1;


__END__
