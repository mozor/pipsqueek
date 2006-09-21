package Handlers::Admin::Advertise;
#
# The admin_advertise command just spits out some information about pipsqueek into the channel
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_advertise'	=> \&admin_advertise,
	};
}


sub get_description 
{ 
	return "Prints out some information about PipSqueek";
}

sub get_usage
{
	return "advertise";
}

sub admin_advertise
{
	my $bot = shift;
	$bot->chanmsg( $bot->version() );
}


1;

