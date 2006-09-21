package Handlers::IRC::CTCP;
#
# This package (should) handle all/most irc_ctcp_* requests
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'irc_ctcp_version'	=> \&irc_ctcp_version,
		'irc_ctcp_ping'		=> \&irc_ctcp_ping,
		'irc_ctcp_action'	=> \&irc_ctcp_action,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;

	if( $type eq 'irc_ctcp_version' ) {
		return "Returns the current pipsqueek version via a CTCP reply";
	} elsif( $type eq 'irc_ctcp_ping' ) {
		return "Sends a CTCP reply with the arguments sent in the original CTCP message";
	} elsif( $type eq 'irc_ctcp_action' ) {
		return "Received whenever someone does /me in a channel or message with us";
	}

}


sub irc_ctcp_version
{
	my $bot = shift;
	my $event = shift;

	$bot->ctcpreply( $event->param('nick'), $bot->version() );

	return 1;
}


sub irc_ctcp_ping
{
	my $bot = shift;
	my $event = shift;

	$bot->ctcpreply( $event->param('nick'), 'PING ' . $event->param('msg') );

	return 1;
}


sub irc_ctcp_action
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nick = $event->param('nick');
	$umgr->param( $nick, { 'actions' => $umgr->param($nick,'actions')+1 } );
}


1; # module loaded successfully

