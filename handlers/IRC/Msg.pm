package Handlers::IRC::Msg;
#
# This package handles just private messages, since it contains code
# that dispatches events to other handlers
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'irc_msg'	=> \&irc_msg,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Received whenever someone private messages the bot" if( /irc_msg/ );
		}
}


sub irc_msg
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');
	my ($msg0,$msg1) = @{$event->param('message')};
	my $pass = $bot->param('admin_password');

	if( defined($msg0) && $msg0 eq $pass )
	{ # valid password? run an admin_foo handler
		if( defined($msg1) ) {
			$bot->{'kernel'}->yield( 'admin_' . $msg1, @{$event->param('args')} );
		}
	}
	else
	{ # no valid password? run an private_foo handler
		if( defined($msg0) ) {
			$bot->{'kernel'}->yield( 'private_' . $msg0, @{$event->param('args')} );
		}
	}
}


1;

