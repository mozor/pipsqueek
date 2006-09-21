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
	my @message = @{$event->param('message')};
	my $cmdprefix = $bot->param('command_prefix');
	my $pass = $bot->param('admin_password');

#	if( defined($message[0]) && $message[0] =~ /^$cmdprefix/ )
#	{ # starts with our command prefix but we're in a private message?  Run a public_foo handler
#		$message[0] =~ s/^$cmdprefix//;
#		$bot->{'kernel'}->yield( 'public_' . $message[0], @{$event->param('args')} );
#		return;
#	}
#	elsif( defined($message[0]) && $message[0] eq $pass )

	if( defined($message[0]) && $message[0] eq $pass )
	{ # valid password? run an admin_foo handler
		if( defined($message[1]) ) {
			$bot->{'kernel'}->yield( 'admin_' . $message[1], @{$event->param('args')} );
		}
	}
	else
	{ # no valid password? run an private_foo handler
		if( defined($message[0]) ) {
			$bot->{'kernel'}->yield( 'private_' . $message[0], @{$event->param('args')} );
		}
	}
}


1;

