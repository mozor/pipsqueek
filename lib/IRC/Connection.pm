package Handlers::IRC::Connection;
#
# This package handles server connection related events
#
use base 'PipSqueek::Handler';
use strict;

sub get_handlers 
{
	my $self = shift;
	return {
		'irc_001'			=> \&irc_001,			# server welcome message
		'irc_connected'		=> \&irc_connected,		# socket established
		'irc_disconnected'	=> \&irc_disconnected,	# socket lost
		'irc_socketerr'		=> \&irc_socketerr,		# socket error
		'irc_error'			=> \&irc_error,			# irc server error
		'irc_433'			=> \&irc_433,			# our nickname was taken
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;

	if( $type eq 'irc_connected' ) {
		return "Handles what happens when the socket is established with the server";
	} elsif( $type eq 'irc_disconnected' ) {
		return "Happens whenever the socket connection to a server is lost";
	} elsif( $type eq 'irc_socketerr' ) {
		return "If there is an error on the actual connection socket, this event is posted";
	} elsif( $type eq 'irc_error' ) {
		return "The IRC server said there was an error, usually accompanied by a connection drop";
	} elsif( $type eq 'irc_001' ) {
		return "This handles the welcome message from a server.  When you receive this".
		" event, it is an indication that you can begin sending commands to the server";
	} elsif( $type eq 'irc_433' ) {
		return "When we connect and another user is using our nickname we'll get this message";
	}
}


sub irc_connected
{
	my $bot = shift;
	my $event = shift;

	print "Connection to ",$event->param('sender')," established\n";

	return 1;
}


sub irc_disconnected
{
	my $bot = shift;
	my $event = shift;

	print "Connection to ",$event->param('sender')," lost...\n";
	print "Attempting to reconnect...\n";
	$bot->connect();

	return 1;
}


sub irc_socketerr
{
	my $bot = shift;
	my $event = shift;

	print "Socket Error: ",$event->param('msg'),"\n";

	return 1;
}


sub irc_error
{
	my $bot = shift;
	my $event = shift;
		
	if( $bot->is_shutdown() )
	{
		kill 15,$$; # SIGTERM
		#kill 2,$$; # SIGINT
		#>>> QUIT :PipSqueek v3.0 - http://pipsqueek.l8nite.net/
		#<<< ERROR :Closing Link: PipSqueek2[12-234-200-64.client.attbi.com] (Quit: PipSqueek2)
	}
	print "Error from server: ",$event->param('msg'),"\n";

	return 1;
}


sub irc_001
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	$umgr->param_all( 'active' => 0 );

	$bot->mode('+B');	# most networks require we identify ourselves as a bot
	
	if( $bot->param('nickserv') )
	{
		my $nspass = $bot->param('nickserv_password');
		$bot->privmsg( 'NickServ', qq(IDENTIFY $nspass) );
	}

	if( $bot->param('vhost') )
	{
		my $vuser = $bot->param('vhost_username');
		my $vpass = $bot->param('vhost_password');
		$bot->raw( qq(VHOST $vuser $vpass) );
	}

	$bot->join(); # join the default channel

	return 1;
}


sub irc_433
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $nickname = $bot->param('nickname');
	$bot->nick($bot->param('alternate'));

	if( $bot->param('nickserv') )
	{
		my $nspass = $bot->param('nickserv_password');
		$bot->privmsg( 'NickServ', qq(GHOST $nickname $nspass) );
		$bot->nick($nickname);
		$bot->connect();		# reconnect now
	}
}


1; # module loaded successfully

