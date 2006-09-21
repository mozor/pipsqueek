package Handlers::Admin::Kick;
#
# This package handles kicking users or kickbanning users from the channel
# as of right now, the bot only does one ban *user!*@*, but that may change
# in the future....
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'admin_kick'	=> \&admin_kick,
		'admin_kickban'	=> \&admin_kick,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Kickbans a user from the channel with an optional kick message" if( /admin_kickban/ );
		return "Kicks a user from the channel with an optional kick message" if( /admin_kick/ );
		}
}


sub admin_kick
{
	my $bot = shift;
	my $event = shift;

	my $nick = shift @{$event->param('message')};
	return unless $nick;
	return if $nick eq $bot->param('nickname');

	my $msg = join(' ',@{$event->param('message')});

	unless( $msg )
	{
		my @reasons = (
			qq(<crazyhorse> pwned!),
			qq(Drink Milk.. foo),
			qq(Dial 1-800-COLLECT, and save a buck or two),
			qq(For the Lich King!),
		);
		$msg = $reasons[ rand @reasons ];
	}

	if( $event->param('type') eq 'admin_kickban' ) {
		$bot->ban($nick);
	}
	$bot->kick($nick,$msg);
}


1;


