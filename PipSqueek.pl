#!/usr/bin/perl
#
#	PipSqueek [version 1.4.0]
#	© 2001 l8nite [l8nite@l8nite.net]
#
#	Shouts to slyfx for writing the original pipsqueek
#	Shouts to wolfjourn for beta-testing and providing a host to test and develop on
#
#	Thanks to sub_pop_culture, Aleph, lordjasper, crazyhorse, Wolfjourn, ex0cet, and slyfx for
#	all your help beta testing and improving.
#	Special thanks to Joker who tried valiantly to tell me that my code was dirty :P
#
#	Changelog
#	1.4.0 - complete rewrite to improve buggy code, apply new perl knowledge and remove the reliance on the
#			resource hog l8nite::mysql class, which I thought had been a good idea at first lol.  Amazing what
#			you can learn when you actually read the pod docs ;) In any case, this code is pretty good now.
#
#	Bugs
#	   none reported
#

# Perl pragma to restrict unsafe constructs
use strict;
# Database independent interface for Perl
use DBI;
# perl application kernel with event driven threads
use POE;
# a fully event-driven IRC client module.
use POE::Component::IRC;
# A clone of the classic Eliza program
use Chatbot::Eliza;
# Object interface for AF_INET domain sockets
use IO::Socket::INET;

my $dbh;

my $debug = 1;
my $init_time = time;
my $workingdir = 'C:\L8NITE\PROJECTS\PIPSQU~1\PIPSQU~2.0\\';
my $script_name = 'PipSqueek.pl';

	# PLEASE DO NOT CHANGE THIS VERSION STRING (you can, but I ask you not to)
my $version = 'PipSqueek [version 1.4.0] http://pipsqueek.l8nite.net/';
	# you may use this to append your modification name/version number etc to the advert string above.
my $custom_version = ' - by l8nite';

my $last_command_time;
my $command_flood_toggle = 0;

my $should_i_exit = 0;

my $elizabot;

my %_botinfo;
my %_language;

my (%font_style) = (
	bold	=>	chr(0x02),
);

my (@smiley_faces) = qw#
:) :( :| :/ :\\ :{ :} :] :[
:x :p :X :P ;) ;( ;| ;/ ;\\
;{ ;} ;] ;[ ;x ;p ;f ;F ;P
;X =) =( =| =/ =\\ =[ =] ={
=} =x =X =P =p =O =o :o :O
:D =D ;D ;O ;o :> ;>
#;


####################################################################################################
# Every POE session must handle a special event, _start.  It's used to tell the session that it has
# been successfully instantiated.
# $_[KERNEL] is a reference to the program's global POE::Kernel instance;
# $_[SESSION] is a reference to the session itself.
sub _start
{
	my ($kernel, $session) = @_[KERNEL, SESSION];
	&debug( "Session " . $session->ID . " has started." );

	# if we are not running the same process, make sure the old one is dead
	my ($killpid) = $_botinfo{'process_id'};
	my ($pid) = $$;

	#Kill last process
	&debug( "Current pid: $pid\tOld pid: $killpid" );
	if ( $killpid != $pid ) {
		&debug( "Killing last process" );
		kill( 9, $killpid );
	}

	# update with the new pid
	$dbh->do( q~UPDATE bots SET process_id=~ . $dbh->quote( $pid ) . q~ WHERE id=~ . $dbh->quote( $_botinfo{'id'} ) );
	&loadbot( $_botinfo{'id'} );

	########################
	# Eliza bot inits
	&debug( "Initializing Eliza Chat Interface" );
	rand( time ^ ($$ + ($$ << 15)) );
	$elizabot = new Chatbot::Eliza $_botinfo{'nickname'};
	########################

	# Set up our IRC connection
	&debug( 'Connecting to: ' . $_botinfo{'server_name'} . ':' . $_botinfo{'server_port'} );

	# Uncomment this to turn on more verbose POE debugging information.
	# $session->option( trace => 1 );

	# Make an alias for our session, to keep it from getting GC'ed (garbage collected).
	$kernel->alias_set( $_botinfo{'nickname'} );

	# Ask the IRC component to send us all IRC events it receives. This
	# is the easy, indiscriminate way to do it.
	$kernel->post( 'pipsbot', 'register', 'all');

	# Setting Debug to 1 causes P::C::IRC to print all raw lines of text
	# sent to and received from the IRC server. Very useful for debugging.
	$kernel->post( 'pipsbot', 'connect', {
					Debug	 => ( $debug == 2 ? 1 : 0 ),
					Nick	 => $_botinfo{'nickname'},
					Server	 => $_botinfo{'server_name'},
					Port	 => $_botinfo{'server_port'},
					Username => $_botinfo{'nickname'},
					Ircname  => $version,
					}
	);
}


###########################################################################
# The POE _stop event is special but, handling it is not required.	It's
# used to tell a session that it's about to be destroyed.  _stop
# handlers perform shutdown things like resource cleanup or
# termination logging.
sub _stop
{
	my ($kernel) = $_[KERNEL];

	$kernel->post( 'pipsbot', 'quit', $version );
	$kernel->alias_remove( $_botinfo{'nickname'} );

	$dbh->disconnect();

	&debug( "Session " . $_[SESSION]->ID . " has stopped." );
}




















sub _default
{
	my ($state, $event, $args) = @_[STATE, ARG0, ARG1];
	$args ||= [];

	# Uncomment for noisy operation.
	# print "$state -- $event @$args\n";
}


###########################################################################
sub irc_error
{
	my $err = $_[ARG0];
	print "Server error occurred! $err\n";
}


###########################################################################
sub irc_socketerr
{
	my $err = $_[ARG0];
	print "Couldn't connect to server: $err\n";
}


###########################################################################
# After we successfully log into the IRC server, join a channel.
sub irc_001
{
	my ($kernel) = $_[KERNEL];

	$dbh->do( q~UPDATE users SET active=0 where id=~ . $dbh->quote( $_botinfo{'id'} ) );

	&debug( 'Joining channel: ' . $_botinfo{'channel'} );

	# Tell the server that this is a bot
	$kernel->post( 'pipsbot', 'mode', $_botinfo{'nickname'}, '+ixB' );

	# Message nickname services to identify that we are who we say we are
	$kernel->post( 'pipsbot', 'privmsg', 'NickServ', 'IDENTIFY ' . $_botinfo{'nickserv_password'} );

	# Set ourselves up with the vhost
	if( $_botinfo{'vhost_username'} ne "" ){
		$kernel->post( 'pipsbot', 'sl', 'VHOST ' . $_botinfo{'vhost_username'} . ' ' . $_botinfo{'vhost_password'} );
	}

	# Join our channel
	$kernel->post( 'pipsbot', 'join', $_botinfo{'channel'} );
}


###########################################################################
# What happens when the bot gets disconnected (ping timeout, etc)
sub irc_disconnected
{
	exit if $should_i_exit == 1;

	my ($kernel, $disserver) = @_[KERNEL, ARG0];
	&debug( "Lost connection to server $disserver, reconnecting." );

	# Set up our IRC connection
	&debug( 'Connecting to: ' . $_botinfo{'server_name'} . ':' . $_botinfo{'server_port'} );

	# Setting Debug to 1 causes P::C::IRC to print all raw lines of text
	# sent to and received from the IRC server. Very useful for debugging.
	$kernel->post( 'pipsbot', 'connect', {
					Debug	 => ( $debug == 2 ? 1 : 0 ),
					Nick	 => $_botinfo{'nickname'},
					Server	 => $_botinfo{'server_name'},
					Port	 => $_botinfo{'server_port'},
					Username => $_botinfo{'nickname'},
					Ircname  => $version,
					}
	);
}


#	 irc_ctcp_*
#		 irc_ctcp_whatever events are generated upon receipt of CTCP
#		 messages. For instance, receiving a CTCP PING request generates an
#		 irc_ctcp_ping event, CTCP SOURCE generates an irc_ctcp_source event,
#		 blah blah, so on and so forth. ARG0 is the nick!hostmask of the
#		 sender. ARG1 is the channel/recipient name(s). ARG2 is the text of
#		 the CTCP message.
#
###########################################################################
# CTCP ACTION handler ( /me does something (in the channel) )
sub irc_ctcp_action
{
	my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0 .. ARG2];
	my $nick = (split /!/, $who)[0];
	my $channel_name= @{$where}[0];

	my ($userid) = $dbh->selectrow_array( q~SELECT id FROM users WHERE username=~ . $dbh->quote( $nick ) );

	# Echelon table logging
	$dbh->do(
		q~INSERT INTO echelon (userid, ts, msg, type) VALUES ( ~ .
		$dbh->quote( $userid ) .
		q~, NOW(), ~ .
		$dbh->quote( $msg ) .
		q~, 2 )~
	) if $userid ne "";

#	&process_plaintext( $kernel, $who, $where, $msg );
	$dbh->do( q~UPDATE stats SET actions=actions+1 WHERE userid=~ . $dbh->quote($userid) ) if $userid ne "";
}

###########################################################################
# CTCP Version reply
sub irc_ctcp_version
{
	my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0 .. ARG2];
	my $nick = (split /!/, $who)[0];

	if( not &flood_limit('ctcp',$nick) )
	{
		&debug( "Received CTCP VERSION request from $nick" );
		$kernel->post( 'pipsbot', 'ctcpreply', $nick, "VERSION ${version}${custom_version}" );
	}
}


###########################################################################
# CTCP Ping reply
sub irc_ctcp_ping
{
	my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0 .. ARG2];
	my $nick = (split /!/, $who)[0];

	if( not &flood_limit('ctcp',$nick) )
	{
		&debug( "Received CTCP PING request from $nick" );
		$kernel->post( 'pipsbot', 'ctcpreply', $nick, "PONG! $msg" );
	}
}



###########################################################################
# If we are banned
sub irc_474
{ # <<< :tranquility.net 474 PipSqueek #tranquility :Cannot join channel (+b)

	my ($kernel, $server, $msg) = @_[KERNEL, ARG0, ARG1];
	my ($where) = $msg;

	&debug( "I was banned from $where, unbanning." );

	# Tell the server that this is a bot
	$kernel->post( 'pipsbot', 'mode', $_botinfo{'nickname'}, '+ixB' );

	# Message nickname services to identify that we are who we say we are
	$kernel->post( 'pipsbot', 'privmsg', 'NickServ', 'IDENTIFY ' . $_botinfo{'nickserv_password'} );

	# make chanserv unban us
	$kernel->post( 'pipsbot', 'privmsg', 'ChanServ', "UNBAN $where" );

	# Join the channel
	$kernel->post( 'pipsbot', 'join', $where  );
}


###########################################################################
# If someone is using our nickname
sub irc_433
{ # <<< :tranquility.net 433 * PipSqueek :Nickname is already in use.

	my ($kernel, $server, $msg) = @_[KERNEL, ARG0, ARG1];

	&debug( 'Nickname ' . $_botinfo{'nickname'} . ' was taken, attempting to ghost' );

	$kernel->post( 'pipsbot', 'nick', 'PipsIsGonnaGhostJ0o' );

	# Message nickname services to identify that we are who we say we are
	$kernel->post( 'pipsbot', 'privmsg', 'NickServ', 'GHOST ' . $_botinfo{'nickname'} . ' ' . $_botinfo{'nickserv_password'} );

	$kernel->post( 'pipsbot', 'nick', $_botinfo{'nickname'} );

	&debug( 'Joining channel: ' . $_botinfo{'channel'} );

	# Tell the server that this is a bot
	$kernel->post( 'pipsbot', 'mode', $_botinfo{'nickname'}, '+ixB' );

	# Message nickname services to identify that we are who we say we are
	$kernel->post( 'pipsbot', 'privmsg', 'NickServ', 'IDENTIFY ' . $_botinfo{'nickserv_password'} );

	# Set ourselves up with the vhost
	if( $_botinfo{'vhost_username'} ne "" ){
		$kernel->post( 'pipsbot', 'sl', 'VHOST ' . $_botinfo{'vhost_username'} . ' ' . $_botinfo{'vhost_password'} );
	}

	# Join our channel
	$kernel->post( 'pipsbot', 'join', $_botinfo{'channel'} );
}


###########################################################################
# Someone has joined, what should we do ?
sub irc_join
{
	my ($kernel, $who, $where) = @_[KERNEL, ARG0, ARG1];
	my $nick = (split /!/, $who)[0];
	my $channel_name = $where;

	&debug( "$nick joined channel $channel_name" );

	# tell our database that this user is active in the channel now
	$dbh->do(
		q~UPDATE users SET active=1,username=real_username WHERE bot_id=~ .
		$dbh->quote( $_botinfo{'id'} ) .
		q~AND real_username=~ .
		$dbh->quote( $nick )
	);

	# Don't greet I if it was I that joined the channel, need to kick whomever may have kicked myself </english>
	if( lc($nick) eq lc( $_botinfo{'nickname'} ) )
	{
		my $db_query = $dbh->prepare( q~SELECT username FROM users WHERE enemy=1 AND bot_id=~ . $dbh->quote( $_botinfo{'id'} ) );
		$db_query->execute();
		while( my ($enemy) = $db_query->fetchrow_array() ) {
			my ($kick_message) = &randomLine( "kick_messages" );
			$kernel->post( 'pipsbot', 'kick', $channel_name, $enemy, $kick_message );
		}
		$db_query->finish();
		$dbh->do( q~UPDATE users SET enemy=0 WHERE enemy=1 AND bot_id=~ . $dbh->quote( $_botinfo{'id'} ) );
	}
	else
	{
		# get the language greeting for our bot
		my (%tokens) = ( 'name' => $nick );
		$kernel->post( 'pipsbot', 'privmsg', $channel_name, &miniLanguage($_language{'greeting'},%tokens) ) unless $_language{'greeting'} eq "";
	}
}


###########################################################################
# Someone has left a channel
sub irc_part
{
	my ($kernel, $who, $where) = @_[KERNEL, ARG0, ARG1];
	my $nick = (split /!/, $who)[0];
	my $channel_name = $where;

	&debug( "$nick has left channel $channel_name" );

	# tell the database that the user is no longer active
	$dbh->do( q~UPDATE users SET active=0,last_seen=NOW() WHERE username=~ . $dbh->quote($nick) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) )
}


###########################################################################
# Someone has left the server
sub irc_quit
{
	my ($kernel, $who, $msg) = @_[KERNEL, ARG0, ARG1];
	my $nick = (split /!/, $who)[0];

	&debug( "$nick has quit ( $msg )" );

	# tell the database that the user is no longer active
	$dbh->do( q~UPDATE users SET active=0,last_seen=NOW() WHERE username=~ . $dbh->quote($nick) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) )
}


###########################################################################
# Someone changed the topic
sub irc_topic
{
	my ($kernel, $who, $channel_name, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
	my $nick = (split /!/, $who)[0];

	# Echelon table logging
	my ($userid) = $dbh->selectrow_array( q~SELECT id FROM users WHERE username=~ . $dbh->quote( $nick ) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) );

	$dbh->do( q~INSERT INTO echelon (userid, ts, msg, type) VALUES ( ~
		. $dbh->quote( $userid) .
		', NOW(), ' .
		$dbh->quote( $msg ) .
		', 3 )'
	) if $userid ne "";
	$dbh->do( q~UPDATE stats SET topics=topics+1 WHERE userid=~ . $dbh->quote( $userid ) ) if $userid ne "";
}


###########################################################################
#	 irc_mode
#		 Sent whenever someone changes a channel mode in your presence, or
#		 when you change your own user mode. ARG0 is the nick!hostmask of
#		 that someone. ARG1 is the channel it affects (or your nick, if it's
#		 a user mode change). ARG2 is the mode string (i.e., "+o-b"). The
#		 rest of the args (ARG3 .. $#_) are the operands to the mode string
#		 (nicks, hostmasks, channel keys, whatever).
sub irc_mode
{
	my ($kernel, $who, $channel_name) = @_[KERNEL, ARG0, ARG1];
	my $nick = (split /!/, $who)[0];
	my ($userid) = $dbh->selectrow_array( qq~SELECT id FROM users WHERE username=~ . $dbh->quote( $nick )  . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}));

	# ignore mode changes on ourself
	if( lc($nick) ne lc($_botinfo{'nickname'}) )  {
		$dbh->do( q~UPDATE stats SET modes=modes+1 WHERE userid=~ . $dbh->quote( $userid ) ) if $userid ne "";
	}
}


###########################################################################
# What should we do when someone gets kicked ?
sub irc_kick
{
	my ($kernel, $who, $where, $whom, $msg) = @_[KERNEL, ARG0 .. ARG3];
	my $the_kicker = (split /!/, $who)[0];
	my $channel_name = $where;
	my $person_kicked = $whom;

	&debug( "$person_kicked was kicked from $channel_name by $the_kicker" );

	my ($userid) = $dbh->selectrow_array( q~SELECT id FROM users WHERE username=~ . $dbh->quote( $the_kicker )	. q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) );
	$dbh->do( q~UPDATE stats SET kicks=kicks+1 WHERE userid=~ . $dbh->quote( $userid ) ) if $userid ne "";

	my ($luserid) = $dbh->selectrow_array( q~SELECT id FROM users WHERE username=~ . $dbh->quote( $person_kicked )	. q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}));
	$dbh->do( q~UPDATE stats SET kicked=kicked+1 WHERE userid=~ . $dbh->quote( $luserid ) ) if $luserid ne "";

	if ( lc($person_kicked) eq lc( $_botinfo{'nickname'} ) )
	{
		$dbh->do( q~UPDATE users SET enemy=1 WHERE username=~ . $dbh->quote( $the_kicker ) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) );
		$kernel->post( 'pipsbot', 'join', $channel_name );
	}
	else
	{
		# they left the room technically, so tell the database that the user is no longer active in this channel
		$dbh->do( q~UPDATE users SET active=0,last_seen=NOW() WHERE username=~ . $dbh->quote($person_kicked) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) )
	}
}


###########################################################################
# Gets the names of people in a channel when we enter.
sub irc_353
{ # <<< :tranquility.net 353 PipSqueek = #tranquility :PipSqueek @l8nite Wolfjourn|moretribes @khacrez
	my ($kernel, $server, $msg ) = @_[KERNEL, ARG0, ARG1];
	my ($channel_name,$namelist) = split( /:/, $msg );
	$channel_name =~ s/^.*#/#/gi;
	$channel_name =~ s/ +$//gi;

	my (@names) = split( / /, $namelist );
	# strip out the operator status symbol from each element in the array
	for(0..$#names){$names[$_]=~s/.// if$names[$_]=~m/^[\^\+\@\%]/;}

	&debug( "Channel $channel_name has users: @names" );
	# let the database know that each of these users is active

	my ($namelist) = "@names";
	$namelist = "\"" . $namelist;
	$namelist =~ s/ /\" OR username=\"/gi;
	$namelist .= "\"";
	$dbh->do( qq~UPDATE users SET active=1 WHERE (username=$namelist) AND (bot_id=~ . $dbh->quote($_botinfo{'id'}) . ')' );
}


###########################################################################
# On nickname change
sub irc_nick
{
	my ($kernel, $who, $new_nick) = @_[KERNEL, ARG0, ARG1];
	my $nick = (split /!/, $who)[0];

	&debug( "$nick has changed handles to $new_nick" );

	my ($userid) = $dbh->selectrow_array( qq~SELECT id FROM users WHERE real_username=~ . $dbh->quote( $new_nick )	. q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}));

	if( $userid eq "" )
	{	# they're just changing names
		$dbh->do( q~UPDATE users SET username=~ . $dbh->quote( $new_nick ) . q~ WHERE username=~ . $dbh->quote( $nick ) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) );
	}
	else
	{	# they're changing into someone else's base-name (identifying) # reset this user
		$dbh->do( q~UPDATE users SET username=real_username,active=0 WHERE username=~ . $dbh->quote($nick) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) );
		# reset the user they changed into
		$dbh->do( q~UPDATE users SET username=real_username,active=1 WHERE userid=~ . $dbh->quote($userid) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'})  );
	}
}





###########################################################################
sub irc_public
{
	my ($kernel, $who, $channel_name, $msg) = @_[KERNEL, ARG0 .. ARG2];
	my $nick = (split /!/, $who)[0];
	$channel_name= @{$channel_name}[0];

	my ($userid) = $dbh->selectrow_array( qq~SELECT id FROM users WHERE username=~ . $dbh->quote( $nick )  . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}));
	# Echelon table logging
	$dbh->do(
		q~INSERT INTO echelon (userid, ts, msg, type) VALUES ( ~ .
		$dbh->quote($userid) .
		', NOW(), ' .
		$dbh->quote($msg) .
		', 0 )'
	) if $userid ne "";

	my ($flood_amt) = &flood_limit( 'public', $nick );

	if( $flood_amt == 0 || $_botinfo{'use_flood_detection'} != 1 )
	{
		if( $_botinfo{'use_flood_detection'} == 1 )
		{
			my ($flood_amt,$user_id) = $dbh->selectrow_array(
				q~SELECT flood,id FROM users WHERE id=~ . $dbh->quote($userid)
			);
			$flood_amt = 0 if $flood_amt eq "";
			if( $flood_amt != 0 )
			{
				my ($deduction) = $flood_amt * $_botinfo{'flood_penalty'};
				my ($newscore) = $deduction / $_botinfo{'chars_per_point'} unless $_botinfo{'chars_per_point'} < 1;

				my (%tokens) = (
					name => $nick,
					deduction => $newscore,
					plural => ''
				);

				$tokens{'plural'} = 's' if $newscore != 1;
				$kernel->post( 'pipsbot', 'privmsg', $channel_name, &miniLanguage($_language{'flood_detected'},%tokens) );
				$dbh->do( qq~UPDATE users SET flood=0 WHERE id='$userid'~ ) if $userid ne "";
				$dbh->do( qq~UPDATE stats SET score=score-$deduction WHERE userid='$userid'~ ) if $userid ne "";
			}
		}

		my ($channel_text) = ($msg);

		# Find out if this is a command
		my $command_prefix = $_botinfo{'command_prefix'};
		if( $channel_text =~ m/^\Q$command_prefix\E/ )
		{
			# The first characters were a command prefix, split up the command and the arguments
			my (@temp) = split( / /, $channel_text );
			my ($len) = length $temp[0];
			my ($len2) = length $command_prefix;
			my ($command) = substr( $temp[0], $len2, $len - 1 );
			my (@command_args) = @temp;
			shift @command_args; # get rid of the command part

			# Clean up the command text
			$command =~ s/[^a-zA-Z0-9]//g;

			my ($seconds) = (time - $last_command_time);
			if( $seconds < $_botinfo{'command_flood_limit'} )
			{
				if( $command_flood_toggle == 0 )
				{
					my (%tokens) = (
						name => $nick,
						seconds => $_botinfo{'command_flood_limit'}-$seconds,
						plural => '' );
						$tokens{'plural'} = 's' if ($_botinfo{'command_flood_limit'}-$seconds) != 1;
					$kernel->post( 'pipsbot', 'notice', $nick, &miniLanguage( $_language{'command_delay'}, %tokens ) );
					$command_flood_toggle = 1;
				}
				return;
			}
			else{$command_flood_toggle = 0;}

			if(  $command ne "" )
			{
				&process_command( $kernel, $who, $channel_name, $command, @command_args );
				$last_command_time = time;
			}
			else
			{
				&process_plaintext( $kernel, $who, $channel_name, $msg );
			}
		}
		else{
			&process_plaintext( $kernel, $who, $channel_name, $msg );
		}
	}
	else
	{
		$flood_amt = $flood_amt - $_botinfo{'public_flood_lines'};
		$dbh->do( qq~UPDATE users SET flood=flood+$flood_amt WHERE id=~ . $dbh->quote($userid) );
	}
}


###########################################################################
# Handles plaintext to the bot
sub process_plaintext()
{
	my ($kernel, $who, $channel_name, $msg) = @_;
	my $nick = (split /!/, $who)[0];
	my ($channel_text) = ($msg);

	my ($ctc,$spam_detected) = ($channel_text,0);
	my ($userid) = $dbh->selectrow_array( q~SELECT id FROM users WHERE username=~ . $dbh->quote( $nick ) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) );
#my ($bot_nickname,$eliza,$spam_penalty,$chars_per_point,$use_spam_detection,$user_id) =
# SELECT nickname,eliza_mode,spam_penalty,chars_per_point,use_spam_detection,user_id

	# ANTI-spam CODE GOES HERE
	if( $_botinfo{'use_spam_detection'} == 1 && length $channel_text > 18 )
	{
		# ////// detect long single character spams
		# like : aaaaaaaaaaaaaaaaaaaaaaaaaaaaa
		my $ch = " ";
		$ch = substr( $ctc, int( rand 18 ), 1 ) while($ch eq " ");
		my $len = 0;
		$len++ while( $ctc =~ s/\Q$ch\E//i );
		$spam_detected += $_botinfo{'spam_penalty'} if( ( (length $channel_text) - $len) < 5 );

		# ////// detect spams of the shift+number variety
		# like : @#^%(&@^*(@)!_#)^
		$ctc = $channel_text;
		my ($strip_chars) = '!@#$%^&*()_+=-0987654321~`';
		$ctc =~ s/[\Q$strip_chars\E]//gi;
		$spam_detected += $_botinfo{'spam_penalty'} if( length $ctc < 5 );

		# ////// detect spams on the home row
		# like : ksajflk;afkasfhasjfhaslkjhfalsfhlh
		$ctc = $channel_text;
		my ($strip_chars) = 'asdfghjkl;\'';
		$ctc =~ s/[\Q$strip_chars\E]//gi;
		$spam_detected += $_botinfo{'spam_penalty'} if( length $ctc < 5 );
	}

	if( $spam_detected )
	{
		my ($len) = length $channel_text;
		$len *= $spam_detected;
		my ($newscore) = $len / $_botinfo{'chars_per_point'} unless $_botinfo{'chars_per_point'} < 1;
		my (%tokens) = (
			name => $nick,
			deduction => $newscore,
			plural => '' );
		$tokens{'plural'} = 's' if $newscore != 1;
		$kernel->post( 'pipsbot', 'privmsg', $channel_name, &miniLanguage($_language{'spam_detected'},%tokens) );
		$dbh->do(
			q~UPDATE stats SET score=score-~ .
			$dbh->quote($len) .
			q~ WHERE userid=~ . $dbh->quote($userid)
		) if $userid ne "";
	}
	else
	{
		# update the stats
		my ($len) = length $channel_text;
		my ($words,$smilies) = (0,0);
		$ctc = $channel_text;
		$ctc =~ s/ +/ /gi;
		my (@text) = split( / /, $ctc );
		$words = $#text + 1; # words is number of spaces + 1

		foreach my $smiley (@smiley_faces)
		{
			my ($dctc) = $channel_text;
			$dctc =~ s/\\/\\\\/gi;
			$smilies++ while( $dctc =~ s/\Q$smiley\E// );
		}

		$dbh->do(
			qq~UPDATE stats SET score=score+$len,linecount=linecount+1,words=words+$words,smilies=smilies+$smilies WHERE userid=~ .
			$dbh->quote($userid)
		) if $userid ne "";

		if( $_botinfo{'eliza_mode'} == 1 )
		{
			my $bot_nickname = $_botinfo{'nickname'};
			if( $channel_text =~ m/^$bot_nickname:/i )
			{
				$channel_text =~ s/^$bot_nickname//i;
				$kernel->post( 'pipsbot', 'privmsg', $channel_name, $elizabot->transform( $channel_text ) );
			}
		}
	}
}


###########################################################################
# Handles the valid commands for our bot
sub process_command()
{
	my ($kernel, $who, $channel_name, $command, @command_args ) = @_;
	# Let's find out who is issuing the command by checking in our handy dandy - notebook
	my $nick = (split /!/, $who)[0];

	my (%tokens) = (
		name => $command_args[0],
		person => $nick,
		channel => $channel_name
	);

	# let's just have a little fun if a user tries to perform some sort of lookup on the bot
	if( $command_args[0] eq $_botinfo{'nickname'} )
	{
		if( lc($command) eq "score" || lc($command) eq "rank" ) {
			$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'bot_selfscore'},%tokens) );
		}
		elsif( lc($command) eq "seen" ) {
			$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'bot_selfseen'},%tokens) );
		}
		return;
	}

	# process the commands we have programmed
	if( lc($command) eq "quote" )
	{
		$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &randomLine( "quotes" ) ); # don't you wish all user-programmed functions were this easy ?
	}
	elsif( lc($command) eq "bugtraq" )
	{ # added by ex0cet
		my($bugtraq_host,$vuln_page,$EOLbug,$blankbug) = ("www.securityfocus.com","/vdb/latest.html","\015\012","\015\012\015\012");
		my($securityf_remote) = IO::Socket::INET->new(
			PeerHost => "$bugtraq_host",
			PeerPort => "http(80)",
			Proto => "tcp",
			Timeout => 5
		);

		if($securityf_remote)
		{
			$securityf_remote->autoflush(1);
			print $securityf_remote "GET $vuln_page" . $blankbug;
			my(@bugtraq_results) = <$securityf_remote>;
			close( $securityf_remote );

			my($each_bugresult,@final_links);
			foreach $each_bugresult (@bugtraq_results){
				if($each_bugresult =~ /<A HREF/){
					$each_bugresult =~ s/<LI>//g;
					$each_bugresult =~ s/<A HREF=//g;
					$each_bugresult =~ s/<\/A><BR>//g;
					$each_bugresult =~ s/TARGET=content>/-/g;
					$each_bugresult =~ s/bottom.html/http\:\/\/www\.securityfocus\.com\/vdb\/bottom.html/g;
					push @final_links, "$each_bugresult";
				}
			}
			$tokens{'vulnerability'} = $final_links[0];
			$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'bugtraq_report'},%tokens) );
			close($securityf_remote);
		}
		else {
			$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'bugtraq_error'},%tokens) );
		}
	}
	elsif( lc($command) eq "uptime" )
	{
		my ($uptime) = time - $init_time;
		my $days = int($uptime / 86400);	$uptime = $uptime % 86400;
		my $hours = int($uptime / 3600);	$uptime = $uptime % 3600;
		my $minutes = int($uptime / 60);	$uptime = $uptime % 60;
		my $seconds = $uptime;

		$tokens{'days'} = $days;
		$tokens{'hours'} = $hours;
		$tokens{'minutes'} = $minutes;
		$tokens{'seconds'} = $seconds;

		$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage( $_language{'uptime_report'}, %tokens ) );
	}
	elsif( lc($command) eq "score" )
	{
		my ($nick_to_score) = $nick;
		if( $command_args[0] ne "" ){ $nick_to_score = $command_args[0]; }

		# first we need to see if the person's name they requested is just someone that's on the channel right now
		my ($real_username,$score) = $dbh->selectrow_array(
			q~SELECT real_username,score FROM users,stats WHERE LCASE(users.username)=~ .
			$dbh->quote($nick_to_score) .
			q~ AND users.bot_id=~ . $dbh->quote( $_botinfo{'id'} ) .
			q~ AND stats.userid=users.id~
		);

		if( $real_username eq "" ) {
			# the username they requested wasn't found, so perhaps they were requesting the score of the base username
			($real_username,$score) = $dbh->selectrow_array(
				q~SELECT real_username,score FROM users,stats WHERE LCASE(users.real_username)=~ .
				$dbh->quote($nick_to_score) .
				q~ AND users.bot_id=~ . $dbh->quote( $_botinfo{'id'} ) .
				q~ AND stats.userid=users.id~
			);

			if( $real_username eq "" ) {
				# this user doesn't exist in the database
				$tokens{'name'} = $nick_to_score;
				$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'score_error'},%tokens) );
				return;
			}
		}
		$tokens{'name'} = $real_username;
		$tokens{'score'} = $score / $_botinfo{'chars_per_point'} unless $_botinfo{'chars_per_point'} < 1;
		$tokens{'plural'} = 's' if $tokens{'score'} != 1;
		$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'score_report'},%tokens) );
	}
	elsif( lc($command) eq "rank" ) # an alternative to score, that lists what number you are in the rankings
	{
		my ($nick_to_score) = lc($nick);
		my ($rank_to_score) = "";

		if( $command_args[0] ne "" ) {
			$rank_to_score = $command_args[0];
			if (( $rank_to_score =~ /(\d+)/) && (not($rank_to_score =~ /[a-zA-Z|\\`\[\]\{\}\(\)_\-]/)))
			{
				# they want the persons name associated with this number rank
				my $sth = $dbh->prepare(
					q~SELECT username,real_username,score FROM users,stats WHERE users.bot_id=~ .
					$dbh->quote($_botinfo{'id'}) .
					q~ AND stats.userid=users.id ORDER BY score DESC~
				); $sth->execute();

				my ($rankcounter,$username,$real_username,$score) = (0);
				while( ($username,$real_username,$score) = $sth->fetchrow_array() ){
					$rankcounter++;
					last if $rankcounter == $rank_to_score;
				}
				$sth->finish();

				if( $rankcounter < $rank_to_score ) {
					# this user doesn't exist in the database
					my $rank_error_msg = $_language{'rank_error'};
					$rank_error_msg =~ s/<rank>(.*?)<\/rank>//g;$rank_error_msg = $1;
					$tokens{'rank'} = $rank_to_score;
					$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage( $rank_error_msg, %tokens ) );
					return;
				}

				$tokens{'name'} = $real_username;
				$tokens{'rank'} = $rankcounter;
				$tokens{'score'} = $score / $_botinfo{'chars_per_point'} unless $_botinfo{'chars_per_point'} < 1;
				$tokens{'plural'} = 's' if $tokens{'score'} != 1;
				$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'rank_report'},%tokens) );
			}
			else
			{ # they want the rank of a person's name

				$nick_to_score = lc($command_args[0]);
				# first we need to see if the person's name they requested is just someone that's on the channel right now
				my ($real_username,$score) = $dbh->selectrow_array(
					q~SELECT real_username,score FROM users,stats WHERE LCASE(users.username)=~ .
					$dbh->quote($nick_to_score) .
					q~ AND users.bot_id=~ . $dbh->quote( $_botinfo{'id'} ) .
					q~ AND stats.userid=users.id~
				);

				if( $real_username eq "" )
				{
					# the username they requested wasn't found, so perhaps they were requesting the score of the base username
					($real_username,$score) = $dbh->selectrow_array(
						q~SELECT real_username,score FROM users,stats WHERE LCASE(users.real_username)=~ .
						$dbh->quote($nick_to_score) .
						q~ AND users.bot_id=~ . $dbh->quote( $_botinfo{'id'} ) .
						q~ AND stats.userid=users.id~
					);

					if( $real_username eq "" )
					{
						# this user doesn't exist in the database
						my $rank_error_msg = $_language{'rank_error'};
						$rank_error_msg =~ s/<name>(.*?)<\/name>//g;$rank_error_msg = $1;
						$tokens{'name'} = $nick_to_score;
						$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($rank_error_msg,%tokens) );
						return;
					}
					else
					{
						# we check against the real username
						my $sth = $dbh->prepare(
							q~SELECT username,real_username,score FROM users,stats WHERE users.bot_id=~ .
							$dbh->quote($_botinfo{'id'}) .
							q~ AND stats.userid=users.id ORDER BY score DESC~
						); $sth->execute();

						my ($rankcounter,$username,$real_username,$score) = (0);
						while( ($username,$real_username,$score) = $sth->fetchrow_array() ){
							$rankcounter++;
							last if lc($real_username) eq $nick_to_score;
						}
						$sth->finish();

						$tokens{'name'} = $real_username;
						$tokens{'score'} = $score / $_botinfo{'chars_per_point'} unless $_botinfo{'chars_per_point'} < 1;
						$tokens{'rank'} = $rankcounter;
						$tokens{'plural'} = 's' if $tokens{'score'} != 1;
						$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'rank_report'},%tokens) );
					}
				}
				else
				{
					# we check against the real username
					my $sth = $dbh->prepare(
						q~SELECT username,real_username,score FROM users,stats WHERE users.bot_id=~ .
						$dbh->quote($_botinfo{'id'}) .
						q~ AND stats.userid=users.id ORDER BY score DESC~
					); $sth->execute();

					my ($rankcounter,$username,$real_username,$score) = (0);
					while( ($username,$real_username,$score) = $sth->fetchrow_array() ){
						$rankcounter++;
						last if lc($username) eq $nick_to_score;
					}
					$sth->finish();

					$tokens{'name'} = $real_username;
					$tokens{'score'} = $score / $_botinfo{'chars_per_point'} unless $_botinfo{'chars_per_point'} < 1;
					$tokens{'rank'} = $rankcounter;
					$tokens{'plural'} = 's' if $tokens{'score'} != 1;
					$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'rank_report'},%tokens) );
				}

			}
		}
		else
		{
			my $sth = $dbh->prepare(
				q~SELECT username,real_username,score FROM users,stats WHERE users.bot_id=~ .
				$dbh->quote($_botinfo{'id'}) .
				q~ AND stats.userid=users.id ORDER BY score DESC~
			); $sth->execute();

			my ($rankcounter,$username,$real_username,$score) = (0);
			while( ($username,$real_username,$score) = $sth->fetchrow_array() ){
				$rankcounter++;
				last if lc($username) eq $nick_to_score;
			}
			$sth->finish();

			$tokens{'name'} = $real_username;
			$tokens{'score'} = $score / $_botinfo{'chars_per_point'} unless $_botinfo{'chars_per_point'} < 1;
			$tokens{'rank'} = $rankcounter;
			$tokens{'plural'} = 's' if $tokens{'score'} != 1;
			$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'rank_report'},%tokens) );
		}
	}
	elsif( lc($command) eq "top10" )
	{
		my ($intro_text) = $_language{'score_top10'}; # split out the intro text
		$intro_text =~ s/<intro>(.*?)<\/intro>//gi;$intro_text = $1;
		my ($outtro_text) = $_language{'score_top10'};	  # split out the outtro text
		$outtro_text =~ s/<outtro>(.*?)<\/outtro>//gi;$outtro_text = $1;
		my ($appending) = $_language{'score_top10'};	  # split out the notfinal parameter
		$appending =~ s/<notfinal>(.*?)<\/notfinal>//gi;$appending = $1;
		my ($final_msg) = $intro_text;			# start with the intro text

		my $sth = $dbh->prepare(
			q~SELECT real_username,score FROM users,stats WHERE users.id=stats.userid AND users.bot_id=~ .
			$dbh->quote($_botinfo{'id'}) .
			q~ ORDER BY score DESC LIMIT 10~
		); $sth->execute();

		while( my ($curname,$score) = $sth->fetchrow_array() )
		{
			my ($currmsg) = $_language{'score_top10'};
			$score = $score / $_botinfo{'chars_per_point'} unless $_botinfo{'chars_per_point'} < 1; # avoid people who think they're clever by setting this negative or to 0
			$currmsg =~ s/<outtro>(.*?)<\/outtro>//gi;
			$currmsg =~ s/<intro>(.*?)<\/intro>//gi;
			$currmsg =~ s/<notfinal>(.*?)<\/notfinal>//gi;

			$tokens{'name'} = $curname;
			$tokens{'score'} = $score;
			$tokens{'plural'} = 's' if $score != 1;

			$currmsg = &miniLanguage( $currmsg, %tokens );

			$final_msg .= $currmsg . $appending;
		}
		$sth->finish();

		chop $final_msg for( 1 .. length $appending );	# take off the last appending
		$final_msg .= $outtro_text; 		# append the outtro

		$kernel->post( 'pipsbot', 'privmsg',  $channel_name, $final_msg );
	}
	elsif( lc($command) eq "addme" )
	{
		my ($userid) = $dbh->selectrow_array( qq~SELECT id FROM users WHERE LCASE(real_username)=~ . $dbh->quote( lc($nick) )  . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}));
		# as long as this username doesn't exist, let's add them to our database
		if( $userid eq "" )
		{
			my $newscore = lc($command_args[0]) eq "please" ? 50 * $_botinfo{'chars_per_point'} : 0;

			$dbh->do(
				q~INSERT INTO users (username, real_username, ident, password, last_seen, active, enemy, flood, bot_id) ~ .
				q~VALUES(~ .
				$dbh->quote($nick) . ', ' .
				$dbh->quote($nick) . ',"NOTENABLEDYET","NOTENABLEDYET", NOW(), 1, 0, 0, ' .
				$dbh->quote($_botinfo{'id'}) . ')'
			);
			my ($userid) = $dbh->selectrow_array( qq~SELECT id FROM users WHERE LCASE(real_username)=~ . $dbh->quote( lc($nick) )  . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}));
			$dbh->do(
				q~INSERT INTO stats (userid, words, linecount, actions, smilies, kicks, modes, topics, score) VALUES( ~ .
				$dbh->quote( $userid ) .
				', 0, 0, 0, 0, 0, 0, 0, ' . $dbh->quote($newscore) . ')'
			);

			$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage($_language{'add_to_db'}, %tokens) );
			$kernel->post( 'pipsbot', 'privmsg',  $channel_name, "And for being so polite I gave you 50 more points" ) if lc($command_args[0]) eq "please";
		}
	}
	elsif( lc($command) eq "seen" )
	{
		my ($person) = $command_args[0];
		my ($smsg,$seendate,$active,$days,$hours,$minutes,$seconds);
		return if $person eq "";

		if( $person eq $nick )
		{
			($smsg) = $_language{'seen_yourself'};
		}
		else
		{
			($seendate,$active) = $dbh->selectrow_array(
				q~SELECT ( UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(last_seen) ),active FROM users WHERE real_username=~ .
				$dbh->quote( $person ) .
				q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'})
			);

			if ($seendate eq "" ) {
				($smsg) = $_language{'seen_notfound'};
			}
			elsif( $active == 1 ) {
				($smsg) = $_language{'seen_onchannel'};
			}
			else {
				($smsg) = $_language{'seen_found'};
				$days = int($seendate / 86400); $seendate = $seendate % 86400;
				$hours = int($seendate / 3600); $seendate = $seendate % 3600;
				$minutes = int($seendate / 60); $seendate = $seendate % 60;
				$seconds = $seendate;
			}
		}

		$tokens{'channel'} = $channel_name;
		$tokens{'person'} = $nick;
		$tokens{'nick'} = $person;
		$tokens{'days'} = $days;
		$tokens{'hours'} = $hours;
		$tokens{'minutes'} = $minutes;
		$tokens{'seconds'} = $seconds;

		$kernel->post( 'pipsbot', 'privmsg',  $channel_name, &miniLanguage( $smsg, %tokens ) );
	}
}


###########################################################################
# handles private messages to the bot
sub irc_msg
{ # <<< :l8nite!guth1@netadmin.tranquility.net PRIVMSG PipSqueek :<password> command goes here

	my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0 .. ARG2];
	my $nick = (split /!/, $who)[0];
	my $bot_nickname = @{$where}[0];

	# Echelon table logging
	my ($userid) = $dbh->selectrow_array( q~SELECT id FROM users WHERE username=~ . $dbh->quote( $nick ) . q~ AND bot_id=~ . $dbh->quote($_botinfo{'id'}) );
	$dbh->do( q~INSERT INTO echelon (userid, ts, msg, type) VALUES ( ~ .
		$dbh->quote($userid) .
		', NOW(), ' .
		$dbh->quote($msg) .
		', 1 )'
	) if $userid ne "";

	if( not &flood_limit('priv',$nick) )
	{
		my ($attempted_pw,$command,@command_args) = split( / /, $msg );
		my ($cpw) = crypt( $attempted_pw, $_botinfo{'des_salt'} );
		my (%tokens) = ( person => $nick );

		if( $cpw eq $_botinfo{'control_password'} )
		{
			if( lc($command) eq "restart" )
			{
				my $restart_msg = &miniLanguage( $_language{'restart'}, %tokens );
				$kernel->post( 'pipsbot', 'sl', "QUIT :$restart_msg" );
#				 exec("perl $workingdir/$script_name");
#				 kill(9,$_botinfo{'process_id'});
			}
			if( lc($command) eq "shutdown" )
			{
#				 $restart_msg = &miniLanguage( $_language{'restart'}, %tokens );
				$kernel->post( 'pipsbot', 'sl', "QUIT :Shutdown" );
				$should_i_exit = 1;
#				 kill(9,$_botinfo{'process_id'});
			}
			elsif( lc($command) eq "eliza" )
			{
				$_botinfo{'eliza_mode'} = ($_botinfo{'eliza_mode'} == 1 ? 0 : 1 );$tokens{'status'} = "on" if $_botinfo{'eliza_mode'} == 1;$tokens{'status'} = "off" if $_botinfo{'eliza_mode'} == 0;
#				 $sql->ocQuery( qq~UPDATE bots SET eliza_mode=$eliza WHERE bot_id=$bot_id~ );
				$kernel->post( 'pipsbot', 'privmsg', $_botinfo{'channel'}, &miniLanguage( $_language{'eliza'}, %tokens ) );
			}
			elsif( lc($command) eq "topic" )
			{
				my ($topic_text) = join( ' ', @command_args );
				$kernel->post( 'pipsbot', 'topic', $_botinfo{'channel'}, $topic_text );
			}
			elsif( lc($command) eq "advertise" )
			{
				$kernel->post( 'pipsbot', 'privmsg', $_botinfo{'channel'}, "${version}${custom_version}" );
			}
			elsif( lc($command) eq "reload_configuration" )
			{
				# useful only for switching bot commands on the fly
				&loadbot( $_botinfo{'id'} );
				$kernel->post( 'pipsbot', 'privmsg', $_botinfo{'channel'}, &miniLanguage($_language{'reload_config'},%tokens) );
			}
			elsif( lc($command) eq "op" )
			{
				$kernel->post( 'pipsbot', 'mode', $_botinfo{'channel'}, '+o', $command_args[0] );
			}
			elsif( lc($command) eq "cycle" )
			{
				$kernel->post( 'pipsbot', 'privmsg', $_botinfo{'channel'}, &miniLanguage($_language{'cycle'}, %tokens) );
				$kernel->post( 'pipsbot', 'part', $_botinfo{'channel'} );
				$kernel->post( 'pipsbot', 'join', $_botinfo{'channel'} );
			}
			elsif( lc($command) eq "action" )
			{
				my ($action_text) = join( ' ', @command_args );
				$kernel->post( 'pipsbot', 'ctcp', $_botinfo{'channel'}, "ACTION $action_text" );
			}
			elsif( lc($command) eq "say" )
			{
				my ($message) = join( ' ', @command_args );
				$kernel->post( 'pipsbot', 'privmsg', $_botinfo{'channel'}, $message );
			}
			elsif( lc($command) eq "kickban" )
			{
				my ($person_to_kick) = shift @command_args;
				my ($kick_msg) = join( ' ', @command_args );
				$kick_msg = &randomLine( "kick_messages" ) if( $kick_msg eq "random" );
				$kernel->post( 'pipsbot', 'mode', $_botinfo{'channel'}, '+b', "*${person_to_kick}!*@*" );
				$kernel->post( 'pipsbot', 'kick', $_botinfo{'channel'}, $person_to_kick, $kick_msg );
			}
			elsif( lc($command) eq "kick" )
			{
				my ($person_to_kick) = @command_args[0];
				shift @command_args;
				my ($kick_msg) = join( ' ', @command_args );
				$kick_msg = &randomLine( "kick_messages" ) if( $kick_msg eq "random" );
				$kernel->post( 'pipsbot', 'kick', $_botinfo{'channel'}, $person_to_kick, $kick_msg );
			}
			elsif( lc($command) eq "score" )
			{
				my ($person,$sign,$amount) = @command_args;
				return if $person eq "" || $sign eq "" || $amount eq "" || $sign !~ m/^[+-]/;

				$amount = $amount * $_botinfo{'chars_per_point'};
				my ($increment) = join( '', $sign, $amount );

				my ($userid,$oldscore) = $dbh->selectrow_array(
					q~SELECT id,score FROM users,stats WHERE real_username=~ .
					$dbh->quote( $person ) .
					q~ AND bot_id=~ .
					$dbh->quote($_botinfo{'id'}) .
					q~ AND stats.userid=users.id~
				);
				return if $oldscore eq "";

				$dbh->do( qq~UPDATE stats SET score=score${increment} WHERE userid=~ . $dbh->quote( $userid ) ) if $userid ne "";
				my ($newscore) = $oldscore + ( $sign eq "+" ? $amount : -$amount );

				$oldscore = $oldscore / $_botinfo{'chars_per_point'};
				$newscore = $newscore / $_botinfo{'chars_per_point'};
				$amount = $amount / $_botinfo{'chars_per_point'};
				$increment = join( '', $sign, $amount );

				$tokens{'person'} = $nick;
				$tokens{'channel'} = $_botinfo{'channel'};
				$tokens{'name'} = $person;	# as long as I know what i'm doing (don't confuse these two)
				$tokens{'oldscore'} = $oldscore;
				$tokens{'newscore'} = $newscore;
				$tokens{'increment'} = $increment;
				$kernel->post( 'pipsbot', 'privmsg', $_botinfo{'channel'}, &miniLanguage($_language{'score_change'},%tokens) );
			}
			elsif( lc($command) eq "language" )
			{
				my ($language) = $command_args[0];
				&debug( "Got language request for $language" );

				my ($oldlangid) = $_botinfo{'language_id'};
				my ($oldlang) = $dbh->selectrow_array( q~SELECT name FROM languages WHERE id=~ . $dbh->quote( $oldlangid ) );
				$tokens{'oldlanguage'} = $oldlang;
				$tokens{'newlanguage'} = $language;
				$language = lc($language);
				$_botinfo{'language_id'} = $dbh->selectrow_array( q~SELECT id FROM languages WHERE LCASE(name)=~ . $dbh->quote($language) );

				if( $_botinfo{'language_id'} eq "" ) {
					$_botinfo{'language_id'}=$oldlangid;
					return;
				}

				$dbh->do( q~UPDATE bots SET language_id=~ . $dbh->quote( $_botinfo{'language_id'} ) . q~ WHERE id=~ . $_botinfo{'id'} );
				&loadbot( $_botinfo{'id'} );

				$kernel->post( 'pipsbot', 'privmsg', $_botinfo{'channel'}, &miniLanguage( $_language{'language_changed'}, %tokens ) );
			}
			elsif( lc($command) eq "raw" )
			{
				my ($rawcode) = join( " ", @command_args);
				$kernel->post( 'pipsbot', 'sl', $rawcode );
			}
			elsif( lc($command) eq "help" )
			{
				$kernel->post( 'pipsbot', 'privmsg',  $nick, $version );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "---------------------------" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "usage: /msg $bot_nickname <password> <command> [<args> ]" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "---------------------------" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "say <text> - makes the bot say that text in channel" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "action <text> - the bot does \"/me <text>\"" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "restart - starts the bots perl script over" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "shutdown - causes the bot to exit" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "advertise - displays the bots version number in each channel" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "kick <user> [<message>] - the bot kicks user from channel with alternate kick message (you can set this to \"random\" and the bot will pick one for you!" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "kickban <user> [<message>] - the bot bans and then kicks this user from channel with alternate kick message (you can set this to \"random\" and the bot will pick one for you!" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "cycle - makes the bot leave and rejoin the channel" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "op <user> - the bot will set +o on user in channel" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "reload_configuration - the bot will reload it's config (useless now)" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "score <user> <+/-> <amount> - the bot will change user's score by (+/-) amount" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "language <newlanguage> - the bot will change the language file to language_config.dat" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "topic <newtopic> - the bot will change the topic on it's channel to <newtopic>" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "eliza - toggles eliza mode" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "raw <rawcode> - sends rawcode message to server" );
				$kernel->post( 'pipsbot', 'privmsg',  $nick, "help - yes, it is helpful isn't it?" );
			}
		}
		else
		{
			&debug( "Invalid Authorization for ${nick}!!" );
		}
	}
}












































####################################################################################################
# helps prevent CTCP and message attacks
sub flood_limit
{
	my ($type,$nick) = @_;

	return 0 if $_botinfo{'use_flood_detection'} != 1;

	if( $type eq 'ctcp' )
	{
		$dbh->do(
			q~INSERT INTO flood_check (username,type,time,bot_id) values(~ .
			$dbh->quote( $nick ) .
			q~, 'ctcp', NOW(), ~ .
			$dbh->quote( $_botinfo{'id'} ) . ')'
		);

		my $db_query = $dbh->prepare(
			q~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type='ctcp' AND bot_id=~ .
			$dbh->quote( $_botinfo{'id'} ) .
			q~ AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < ~ .
			$dbh->quote( $_botinfo{'ctcp_flood_seconds'} ) .
			q~ORDER BY utime DESC~
		); $db_query->execute();

		my ($counter) = 0;
		$counter++ while( my ($time) = $db_query->fetchrow_array() );
		$db_query->finish();

		&debug( "CTCP flood detected" ) if $counter > $_botinfo{'ctcp_flood_lines'};
		return ( $counter > $_botinfo{'ctcp_flood_lines'} ? $counter : 0 );
	}
	elsif( $type eq 'priv' )
	{
		$dbh->do(
			q~INSERT INTO flood_check (username,type,time,bot_id) values(~ .
			$dbh->quote( $nick ) .
			q~, 'priv', NOW(), ~ .
			$dbh->quote( $_botinfo{'id'} ) . ')'
		);

		my $db_query = $dbh->prepare(
			q~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type='priv' AND bot_id=~ .
			$dbh->quote( $_botinfo{'id'} ) .
			q~ AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < ~ .
			$dbh->quote( $_botinfo{'private_flood_seconds'} ) .
			q~ORDER BY utime DESC~
		); $db_query->execute();

		my ($counter) = 0;
		$counter++ while( my ($time) = $db_query->fetchrow_array() );
		$db_query->finish();

		&debug( "Private flood detected" ) if $counter > $_botinfo{'private_flood_lines'};
		return ( $counter > $_botinfo{'private_flood_lines'} ? $counter : 0 );
	}
	elsif( $type eq 'public' )
	{
		$dbh->do(
			q~INSERT INTO flood_check (username,type,time,bot_id) values(~ .
			$dbh->quote( $nick ) .
			q~, 'public', NOW(), ~ .
			$dbh->quote( $_botinfo{'id'} ) . ')'
		);

		my $db_query = $dbh->prepare(
			q~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type='public' AND bot_id=~ .
			$dbh->quote( $_botinfo{'id'} ) .
			q~ AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < ~ .
			$dbh->quote( $_botinfo{'public_flood_seconds'} ) .
			q~ORDER BY utime DESC~
		); $db_query->execute();

		my ($counter) = 0;
		$counter++ while( my ($time) = $db_query->fetchrow_array() );
		$db_query->finish();

		&debug( "Public flood detected" ) if $counter > $_botinfo{'public_flood_lines'};
		return ( $counter > $_botinfo{'public_flood_lines'} ? $counter : 0 );
	}
}































###########################################################################
# my mini language processor thing for report messages
sub miniLanguage
{
	my ($message,%tokens) = @_;
	foreach my $tok ( keys( %tokens ) )
	{
		if( $tokens{$tok} !~ /\D/ ) # if the value of this is a number
		{
			my (@parts) = split ( /<notzero>/, $message ); # Break our message into <notzero> sized chunks
			my ($counter) = 0;
			foreach(@parts){ $parts[$counter] = "<notzero>" . $parts[$counter] if $parts[$counter] =~ m/<\/notzero>/i; $counter++; }
			foreach my $insider (@parts)
			{
				if( $insider =~ m/<notzero>(.*?)::${tok}::(.*?)<\/notzero>/ )	# and it's surround by notzero tags
				{
					if( $tokens{"${tok}"} == 0 )	# and it is equal to 0 we remove everything
					{
						$insider =~ s/<notzero>(.*?)::${tok}::(.*?)<\/notzero>//gi;
					}
					else	# we remove the <notzero> tags
					{
						$insider =~ s/<\/*notzero>//gi;
					}
				}
				# lets replace the token with it's value now
				$insider =~ s/::${tok}::/$tokens{$tok}/gi;
			}
			$message = join( '', @parts );
		}
		else { # lets replace the token with it's value now
			$message =~ s/::${tok}::/$tokens{$tok}/gi;
		}
	}

	# go through and replace plural values
	my (@parts) = split( /::plural::/, $message );
	foreach my $part (@parts)
	{
		$part =~ s/\D//gi;
		my ($ch) = '';
		$ch = 's' if( $part != 1 );
		$message =~ s/^(.*?)::plural::/${1}${ch}/;
	}

	$message =~ s/<\/*b>/$font_style{'bold'}/gi;
	return $message;
}





###########################################################################
# Returns a random line from the specified database table
# (assumes a rowid and bot_id column are present)
sub randomLine()
{
	my ($table_name) = @_;
	my ($counter,$rowcount) = (0,0);
	my (@rowids);
	my $db_query = $dbh->prepare( qq~SELECT id FROM $table_name WHERE bot_id=~ . $dbh->quote($_botinfo{'id'}) );
	$db_query->execute();
	while( my($rowid) = $db_query->fetchrow_array() ){ $rowids[$counter] = $rowid; $counter++; $rowcount=$rowid if($rowid > $rowcount); print "#" if $debug == 1; }
	$db_query->finish();

	my ($random_rowid,$flag) = ('',0);
	while( $flag == 0 ){
		print "#" if $debug == 1;
		srand;
		$random_rowid = int( rand $rowcount ) + 1;
		foreach (@rowids){ $flag = 1 if( $_ == $random_rowid ); }
	}

	my ($message) = $dbh->selectrow_array( qq~SELECT message FROM $table_name WHERE id=$random_rowid~ );
	return $message;
}
























####################################################################################################
# Mutator for bot data
####################################################################################################
# Accessor for bot data
####################################################################################################
# Mutator for language data
####################################################################################################
# Accessor for language data
####################################################################################################
# loads the language and bot data
sub loadbot
{
	my $id = shift;

	my $db_query = $dbh->prepare(
		q~SELECT
			id, process_id, server_name, server_port, vhost_username, vhost_password, channel, nickname, nickserv_password,
			control_password, des_salt, language_id, command_prefix, command_flood_limit, chars_per_point, use_spam_detection,
			spam_penalty, use_flood_detection, ctcp_flood_lines, ctcp_flood_seconds, private_flood_lines, private_flood_seconds,
			public_flood_lines, public_flood_seconds, flood_penalty, eliza_mode FROM bots WHERE id =~ . $dbh->quote( $id )
	); $db_query->execute();
	my $biref = $db_query->fetchrow_hashref('NAME_lc');
	%_botinfo = %{$biref};
	$db_query->finish();
	undef $db_query;


	my $db_query = $dbh->prepare(
		q~SELECT id, name, greeting, score_report, score_error, rank_report, rank_error, score_top10, add_to_db, command_delay, spam_detected,flood_detected, restart, reload_config, cycle, score_change, seen_found, seen_notfound, seen_yourself, seen_onchannel,bot_selfscore, bot_selfseen, language_changed, eliza, bugtraq_report, bugtraq_error, uptime_report FROM languages WHERE id =~ .
		$dbh->quote( $_botinfo{'language_id'} )
	); $db_query->execute();
	my $lref = $db_query->fetchrow_hashref('NAME_lc');
	%_language = %{$lref};
	$db_query->finish();
}






####################################################################################################
# program entry point
MAIN:
{
	# since the database connected, let's extract the bot's info and the
	my @lines;
	open( BOTINFO, 'bot.conf' );
	@lines = <BOTINFO>;chomp(@lines);
	close(BOTINFO);
	my $bot_id = $lines[0];
	my $db_name = $lines[1];
	my $db_user = $lines[2];
	my $db_pass = $lines[3];
	$dbh = DBI->connect('DBI:mysql:' . $db_name,$db_user,$db_pass,
			{ RaiseError => 1, AutoCommit => 1, LongReadLen => 1024 }
		  ) or die "Could not open database connection";

	&loadbot($bot_id);

	POE::Component::IRC->new( 'pipsbot' ) or die "Can't instantiate new IRC component!";

	POE::Session->new(
	'main' => [
		qw#
		_start
		_stop
		irc_001
		irc_474
		irc_433
		irc_socketerr
		irc_error
		irc_part
		irc_quit
		irc_join
		irc_ctcp_version
		irc_ctcp_ping
		irc_ctcp_action
		irc_public
		irc_disconnected
		irc_mode
		irc_msg
		irc_nick
		irc_topic
		irc_kick
		irc_353
		#
	]);

	$poe_kernel->run();

	exit 0;
}


####################################################################################################
# outputs the string if debug == 1
sub debug(){
	my ($message) = @_;
	print $message . "\n" if $debug == 1;
}


