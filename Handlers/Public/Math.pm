package Handlers::Public::Math;
#
# This package interprets the arguments as a math statement, and displays the result
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_math' => \&math,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Returns the results of evaluating the math expression given" if( /public_math/ );
	}
}


sub math
{
	my $bot = shift;
	my $event = shift;

	my $msg = $event->param('msg') || return;

	if( $msg =~ /[^\+\-\*\/\^\%\(\)\[\]0123456789\. ]/ )
	{
		return $bot->chanmsg( "Invalid characters detected, only + - * / ^ % ( ) [ ] . and 0-9 are allowed." );
	}
	
	$msg =~ s/\^/\*\*/g;
	$msg =~ s/\[/\(/g;
	$msg =~ s/\]/\)/g;

	my $x;
	my $eval = '$x = ' . "$msg";
	eval $eval || return $bot->chanmsg( "Error: $!" );

	$bot->chanmsg( "$msg = $x" );
}


1;

