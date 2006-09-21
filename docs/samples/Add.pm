package Handlers::Custom::Add;
#
# Handles !add <num1> <num2>
# a supplement to the 'writing modules' page
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_add' => \&public_add
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Adds two numbers and displays the result" if( /public_add/ );
	}
}


sub public_add
{
	my $bot = shift;
	my $event = shift;

	my $num1 = $event->param('message')->[0];
	my $num2 = $event->param('message')->[1];

	if( !(defined $num1 && defined $num2) or $num1 =~ /[^0-9]/ or $num2 =~ /[^0-9]/ )
	{
		return $bot->chanmsg( "Invalid parameters" );
	}

	my $res = $num1 + $num2;
	$bot->chanmsg( "$num1 + $num2 = $res" );
}


1;

