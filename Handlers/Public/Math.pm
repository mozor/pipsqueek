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
	return "Returns the results of evaluating the math expression given";
}

sub get_usage
{
	return "!math <mathematical expression>";
}

sub math
{
	my $bot = shift;
	my $event = shift;

	my $msg = $event->param('msg') || return;
	$msg = "$msg";
	$msg =~ tr/[]/()/; # only normal parens
	$msg =~ s/\^/\*\*/g; # perl's exponent operator
	$msg =~ s/\s*//g; # no need for spaces

	if( $msg =~ /[^\+\-\*\/\%\(\)0-9\.\ e]/ || $msg !~ /^[0-9\(\-]/ ) {
		return $bot->chanmsg( "Invalid expression." );
	}

	my $x;
	my $eval = '$x = ' . $msg;

	local $^W=0;
	eval $eval;

	if( defined($x) ) {
		if( $x =~ /[^\+\-\*\/\%\(\)0-9\.\ einf]/ ) {
			return $bot->chanmsg( "Invalid expression." );
		}
		$bot->chanmsg( "$msg = $x" );
	} else {
		if( $@ ) { $bot->chanmsg( "Error: $@" ); }
		else { $bot->chanmsg("Perl didn't like it, but I don't know why."); }
	}
}


1;

