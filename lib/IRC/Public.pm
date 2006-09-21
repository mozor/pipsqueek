package Handlers::IRC::Public;
#
# This package handles just public messages, since it contains code
# that dispatches events to other handlers
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'irc_public'	=> \&irc_public,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Received whenever someone says something in a channel" if( /irc_public/ );
		}
}


sub irc_public
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');
	my @message = @{$event->param('message')};	
	my $cmdprefix = $bot->param('command_prefix');

	if( defined($message[0]) && $message[0] =~ /^$cmdprefix/ )
	{ # starts with our command prefix? run a public_foo handler
		$message[0] =~ s/^$cmdprefix//;
		$bot->{'kernel'}->yield( 'public_' . $message[0], @{$event->param('args')} );
		return;
	}


	if( $bot->param('capsstop') )
	{
		my $caps_percent = $bot->param('capsstop_percent');
		my $caps_minlength = $bot->param('capsstop_minlength');

		my $msg = $event->param('msg');
		my $len = length($msg); # divide by zero bug here
		my $numcaps = ($msg =~ tr/A-Z/A-Z/);
		my $percent = 0;
		eval { $percent = ($numcaps / $len) * 100; };

		if( $len > $caps_minlength && $percent > $caps_percent )
		{
			$bot->kick( $nick, 'TURN OFF YOUR CAPSLOCK!' );
		}
	}


	my $user = $umgr->user($nick);
	return unless $user;	# only real users are scored 

	my $smiles = 0;
	my $msg = $event->param('msg');
	$smiles++ while( $msg =~ s/[\:\;\=][\-o]?[\)\(\|\/\\\{\}\]\[XxFfPpOoDdCc\>]// );

	my $lines = $user->{'lines'} + 1;
	my $words = $user->{'words'} + scalar(@message);
	my $chars = $user->{'chars'} + length($event->param('msg'));
	$smiles += $user->{'smiles'};

	if( scalar(@message) == 1 && ( $message[0] =~ /^\s*\*/ || $message[0] =~ /\*\s*$/ ) )
	{
		# if they only said one line, and it was like  *foo, or foo*, then it's a correction of their
		# previous line (spelling error fix), and we will ignore it 
		$lines = $user->{'lines'};
		$words = $user->{'words'};
	}

	$umgr->param( $nick, {'lines' => $lines, 'words' => $words, 'chars' => $chars, 'smiles' => $smiles } );
}


1;

