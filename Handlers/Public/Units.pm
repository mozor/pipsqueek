package Handlers::Public::Units;
#
# This handler does unit conversion
#
use base 'PipSqueek::Handler';
use Math::Units qw(convert);
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_units' => \&public_units,
	};
}


sub get_description 
{ 
	return "Converts between various units";
}

sub get_usage
{
	return "!units <amount> <from> <to>";
}


sub public_units
{
	my $bot = shift;
	my $event = shift;

	my $amt = $event->param('message')->[0];
	my $from = $event->param('message')->[1];
	my $to = $event->param('message')->[2];

	eval {
		my $final = convert( $amt, $from, $to );
		return $bot->chanmsg("$amt $from = $final $to");
	};
	
	if( $@ ){ 
		$bot->chanmsg("Error in input");
	}
}



1;


