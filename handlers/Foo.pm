package Handlers::Type::Foo;
#
# This package handles something
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'type_foo' => \&type_foo,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "We do foobar" if( /type_foo/ );
	}
}


sub type_foo
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	$bot->chanmsg("Foo Foo Foo!");
}


1;

