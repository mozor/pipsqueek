#!/usr/bin/perl

#
#	PipSqueek [version 1.2.1-mysql]
#	© 2001 l8nite [l8nite@l8nite.net]
#	Shouts to trapper for the original ideas present in his subordinate bot
#	Shouts to slyfx for writing the original pipsqueek
#
#	Thanks to sub_pop_culture, Aleph, lordjasper, crazyhorse, Wolfjourn, and slyfx for
#	all your help beta testing and improving.
#
#	Changelog
#	1.2.1 - Added eliza module support
#

push(@INC, ".");

#Modules
use strict;
use l8nite::mysql;	# for mysql database
use Net::IRC;		# for IRC connection
use Chatbot::Eliza;	# the eliza interface 

# bot globals
my ($debug) = 0;

my ( $db_name, $db_user, $db_pass );
my ($workingdir) = "";
my ($script_name) = "";
my ($bot_id) = "";

my ($language_id);

my ($sql) = new l8nite::mysql;
my ($irc_module) = new Net::IRC;
my ($irc_server_connection);

my ($elizabot);


my (%font_style) = (
	bold	=>	chr(0x02),
);


my ($version) = "PipSqueek [version 1.2.1-mysql]";
my ($accepted_characters) = ' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890~!@#$%^&*()_+`- =[]{}:<>,.?/|';
my ($command_characters) = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
my ($last_command_time);
my ($command_flood_toggle) = 0;


###########################################################################
####        The main function is at the bottom of the script =)        ####
###########################################################################



###########################################################################
# Returns a random line from the specified database table
# (assumes a rowid and bot_id column are present)
sub randomLine()
{
	my ($table_name) = @_;
	&debug( "Retrieving a random line from: $table_name" );

	my ($counter) = 0;
	my ($rowcount) = 0;
	$sql->doQuery( qq~SELECT rowid FROM $table_name WHERE bot_id=$bot_id~ );
	my (@rowids);
	while( my($rowid) = $sql->getResults ){	$rowids[$counter] = $rowid; $counter++; $rowcount=$rowid if($rowid > $rowcount); }
	$sql->finishQuery();

	my ($random_rowid);
	my ($flag) = 0;
	while( $flag == 0 )
	{
		srand;
		$random_rowid = int( rand $rowcount ) + 1;
		foreach (@rowids){ $flag = 1 if( $_ == $random_rowid );	}
	}

	my ($message) = $sql->oneShot( qq~SELECT message FROM $table_name WHERE rowid=$random_rowid~ );

	return $message;
}


###########################################################################
# Handles some messages you get when you connect
sub on_init
{
	my ($self, $event) = @_;
	my (@args) = ($event->args);
	shift (@args);
	&debug( "*** @args" );
}

###########################################################################
# What to do when the bot successfully connects.
sub on_connect
{
	my ($self, $event) = @_;
	$sql->doQuery( qq~UPDATE users SET active=0 where bot_id=$bot_id~ );
	$sql->finishQuery();

	my ($nickname,$password,$vhostuser,$vhostpass,$channel) = $sql->oneShot( qq~SELECT nickname,nickserv_password,vhost_username,vhost_password,channel FROM bots WHERE bot_id=$bot_id~ );

	&debug( "Joining channel: $channel" );

	# Tell the server that this is a bot
	$self->sl("MODE $nickname +B");

	# Message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $password");

	# Set ourselves up with the vhost
	if( $vhostuser ne "" ){
		$self->sl("VHOST $vhostuser $vhostpass");
	}

	# Join our channel
	$self->join( $channel );
}


###########################################################################
# What happens when the bot gets disconnected (ping timeout, etc)
sub on_disconnect
{
	my ($self, $event) = @_;
	&debug( "Bot was disconnected from network, reconnecting" );
	$self->connect();
}


###########################################################################
# CTCP Version reply
sub on_version 
{
	my ($self, $event) = @_;
	my $nick = $event->nick;

	if( not &flood_limit("ctcp",$nick) )
	{
		&debug( "Received CTCP VERSION request from $nick" );
		$self->ctcp_reply($nick, $version);
	}
}


###########################################################################
# CTCP Ping reply
sub on_ping
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;

	if( not &flood_limit("ctcp",$nick) )
	{
		my ($arg) = ($event->args);
		&debug( "Received CTCP PING request from $nick" );
		$self->ctcp_reply($nick, "PONG! $arg");
	}
}


###########################################################################
# Someone has joined, what should we do ?
sub on_join
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($channel_name) = ($event->to);

	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/); # strip out the operator status symbol

	&debug( "$nick joined channel $channel_name" );

	# tell our database that this user is active in the channel now
	$sql->ocQuery( qq~UPDATE users SET active=1,username=real_username WHERE bot_id=$bot_id AND real_username="$nick"~ );

	my ($nickname) = $sql->oneShot( qq~SELECT nickname FROM bots WHERE bot_id=$bot_id~ );

	# Don't greet I if it was I that joined the channel, need to kick whomever may have kicked myself </english>
	if( $nick eq $nickname )
	{
		my (@enemies);
		my ($counter) = 0;
		$sql->doQuery( qq~SELECT username FROM users WHERE enemy=1 AND bot_id=$bot_id~ );
		while( my($enemy) = $sql->getResults() ){ $enemies[$counter] = $enemy; $counter++; }
		$sql->finishQuery();

		my ($enemy);
		foreach $enemy (@enemies)
		{
			my ($kick_message) = &randomLine( "kick_messages" );
			$self->kick( $channel_name, $enemy, $kick_message );
		}
		$sql->ocQuery( qq~UPDATE users SET enemy=0 WHERE enemy=1 AND bot_id=$bot_id~ );
	}
	else
	{
		# get the language greeting for our bot
		my ($greeting) = $sql->oneShot( qq~SELECT greeting FROM languages WHERE language_id=$language_id~ );
		my (%tokens) = (
			'name' => $nick
		);
		$self->privmsg($channel_name, &miniLanguage($greeting,%tokens) ) unless $greeting eq "";
	}
}


###########################################################################
# Someone has left a channel
sub on_part
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($channel_name) = $event->to;

	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/); # strip out the operator status symbol

	&debug( "$nick has left channel $channel_name" );

	# tell the database that the user is no longer active
	$sql->ocQuery( qq~UPDATE users SET active=0,last_seen=NOW() WHERE username="$nick" AND bot_id=$bot_id~ );
}


###########################################################################
# Someone has left the server
sub on_quit
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;

	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/); # strip out the operator status symbol

	&debug( "$nick has quit the irc server" );

	# tell the database that the user is no longer active
	$sql->ocQuery( qq~UPDATE users SET active=0,last_seen=NOW() WHERE username="$nick" AND bot_id=$bot_id~ );
}


###########################################################################
# On nickname change
sub on_nick
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($new_nick) = ($event->args);

	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/); # strip out the operator status symbol

	&debug( "$nick has changed handles to $new_nick" );

	my ($userid) = $sql->oneShot( qq~SELECT user_id FROM users WHERE real_username="$new_nick" AND bot_id=$bot_id~ );

	if( $userid eq "" )
	{	# they're just changing names
		$sql->ocQuery( qq~UPDATE users SET username="$new_nick" WHERE username="$nick" AND bot_id=$bot_id~ );
	}
	else
	{	# they're changing into someone else's base-name (identifying) # reset this user
		$sql->ocQuery( qq~UPDATE users SET username=real_username,active=0 WHERE username="$nick" AND bot_id=$bot_id~ );

		# reset the user they changed into
		$sql->ocQuery( qq~UPDATE users SET username=real_username,active=1 WHERE user_id=$userid AND bot_id=$bot_id~ );
	}
}


###########################################################################
# What should we do when someone gets kicked ?
sub on_kick
{
	my ($self, $event) = @_;
	my ($the_kicker) = ($event->nick);
	my ($person_kicked) = ($event->to);
	my ($channel_name) = ($event->args);

	&debug( "$person_kicked was kicked from $channel_name by $the_kicker" );

	my ($nickname) = $sql->oneShot( qq~SELECT nickname FROM bots WHERE bot_id=$bot_id~ );

	if ( $person_kicked eq $nickname )
	{
		$sql->ocQuery( qq~UPDATE users SET enemy=1 WHERE username="$the_kicker" AND bot_id=$bot_id~ );
		$self->join($channel_name);
	}
	else
	{
		# they left the room technically, so tell the database that the user is no longer active in this channel
		$sql->ocQuery( qq~UPDATE users SET active=0 WHERE username="$person_kicked" AND bot_id=$bot_id~ );
	}
}


###########################################################################
# If we are banned
sub banned
{
	my ($self, $event) = @_;
	my ($dummy,$channel_name) = ($event->args);

	&debug( "I was banned from $channel_name, unbanning." );

	my ($nickname,$password) = $sql->oneShot( qq~SELECT nickname,nickserv_password FROM bots WHERE bot_id=$bot_id~ );

	# let's make sure we are who we want to be first
	$self->sl("NICK $nickname");

	# message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $password");

	# make chanserv unban us
	$self->privmsg("ChanServ", "UNBAN $channel_name");

	$self->join( $channel_name );
}


###########################################################################
# If someone is using our nickname
sub on_nick_taken
{
	my ($self, $event) = @_;

	my ($nickname,$password,$vhostuser,$vhostpass,$channel) = $sql->oneShot( qq~SELECT nickname,nickserv_password,vhost_username,vhost_password,channel FROM bots WHERE bot_id=$bot_id~ );

	&debug( "Nickname $nickname was taken, attempting to ghost\n" );

	$self->sl("NICK b1shKill3r2X");
	$self->privmsg("NickServ", "GHOST $nickname $password");
	$self->sl("NICK $nickname");

	&debug( "Joining channel: $channel" );

	# Tell the server that this is a bot
	$self->sl("MODE $nickname +B");

	# Message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $password");

	# Set ourselves up with the vhost
	if( $vhostuser ne "" ){
		$self->sl("VHOST $vhostuser $vhostpass");
	}

	# Join our channel
	$self->join( $channel );
}


###########################################################################
# Gets the names of people in a channel when we enter.
sub on_names
{
	my ($self, $event) = @_;

	if( $event->type eq "namreply" )
	{
		my (@args) = ($event->args);
		my (@names) = split( / /, $args[3] );
		my ($channel_name) = $args[2];

		&debug( "Channel $channel_name has users: @names" );

		# let the database know that each of these users is active
		my ($counter) = 0;
		my ($nick);
		foreach $nick (@names)
		{
			# strip out the operator status symbol
			$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);
			$names[$counter] = $nick;
			$counter++;
		}

		my ($namelist) = "@names";		# l8nite lubs perl!
		$namelist = "\"" . $namelist;		# l8nite lubs perl!
		$namelist =~ s/ /\" OR username=\"/gi;	# l8nite lubs perl!
		$namelist .= "\"";			# l8nite lubs perl!
		$sql->ocQuery( qq~UPDATE users SET active=1 WHERE (username=$namelist) AND (bot_id=$bot_id)~ );
	}
}


###########################################################################
# What to do when we receive channel text.
sub on_public
{
	my ($self, $event) = @_;
	my ($nick) = ($event->nick);
	my ($channel_name) = ($event->to);

	my ($use_flood_detection,$flood_penalty,$chars_per_point,$command_prefix,$command_delay,$flood_public_lines) = 
	$sql->oneShot( qq~SELECT use_flood_detection,flood_penalty,chars_per_point,command_prefix,command_flood_limit,public_flood_lines FROM bots WHERE bot_id=$bot_id~ );

	my ($flood_amt) = &flood_limit( "public", $nick );
	if( $flood_amt == 0 || $use_flood_detection != 1 )
	{
		if( $use_flood_detection == 1 )
		{
			my ($flood_amt) = $sql->oneShot( qq~SELECT flood FROM users WHERE username="$nick" AND bot_id=$bot_id~ );
			$flood_amt = 0 if $flood_amt eq "";
			if( $flood_amt != 0 ){
				my ($deduction) = $flood_amt * $flood_penalty;
				my ($newscore) = $deduction / $chars_per_point unless $chars_per_point < 1;

				my ($flood_detected_msg) = $sql->oneShot( qq~SELECT flood_detected FROM languages WHERE language_id=$language_id~ );
				my (%tokens) = (
					name => $nick,
					deduction => $newscore,
					plural => '' );
					$tokens{'plural'} = 's' if $newscore != 1;
				$self->privmsg( $channel_name, &miniLanguage($flood_detected_msg,%tokens) );
				$sql->ocQuery( qq~UPDATE users SET flood=0,score=score-$deduction WHERE username="$nick" AND bot_id=$bot_id~ );
			}
		}

		my ($channel_text) = ($event->args);

		# Output the text if debug = 2 ( chat-logging mode )
		print "<$nick> $channel_text\n" if $debug == 2;

		# Find out if this is a command
		if( $channel_text =~ m/^$command_prefix/ )
		{
			# The first characters were a command prefix, now make sure it's not been disabled by our config file
			my (@temp) = split( / /, $channel_text );
			my ($len) = length $temp[0];
			my ($len2) = length $command_prefix;
			my ($command) = substr( $temp[0], $len2, $len - 1 );
			my (@command_args) = @temp;
			shift @command_args; # get rid of the command part

			# Clean up the command text
			$command =~ s/[^\Q$command_characters\E]//g;

			my ($seconds) = (time - $last_command_time);
			if( $seconds < $command_delay )
			{
				if( $command_flood_toggle == 0 )
				{
					my ($command_delay_msg) = $sql->oneShot( qq~SELECT command_delay FROM languages WHERE language_id=$language_id~ );
					my (%tokens) = (
						name => $nick,
						seconds => $command_delay-$seconds,
						plural => '' );
						$tokens{'plural'} = 's' if $seconds != 1;
				    	$self->notice( $nick, &miniLanguage( $command_delay_msg, %tokens ) );
					$command_flood_toggle = 1;
				}
				return;
			}
			else{$command_flood_toggle = 0;}

			if(  $command ne "" )
			{
				&process_command( $self, $event, $command, @command_args );
				$last_command_time = time;
			}
			else
			{
				&process_plaintext( $self, $event );
			}
		}
		else{
			&process_plaintext( $self, $event );
		}
	}
	else
	{
		$flood_amt = $flood_amt - $flood_public_lines;
		$sql->ocQuery( qq~UPDATE users SET flood=flood+$flood_amt WHERE username="$nick" AND bot_id=$bot_id~ );
	}
}


###########################################################################
# Handles plaintext to the bot
sub process_plaintext()
{
	my ($self, $event) = @_;
	my ($nick) = ($event->nick);
	my ($channel_text) = ($event->args);
	my ($channel_name) = ($event->to);

	# Clean up the channel text
	$channel_text =~ s/[^\Q$accepted_characters\E]//g;

	my ($channel_text_copy) = $channel_text;

	my ($bot_nickname, $eliza,$spam_penalty,$chars_per_point,$use_spam_detection) = $sql->oneShot( qq~SELECT nickname,eliza_mode,spam_penalty,chars_per_point,use_spam_detection FROM bots WHERE bot_id=$bot_id~ );

	my ($spam_detected) = 0;
	# ANTI-spam CODE GOES HERE
	if( $use_spam_detection == 1 && length $channel_text > 18 )
	{
		# ////// detect long single character spams
		# like : aaaaaaaaaaaaaaaaaaaaaaaaaaaaa
			my ($ch);
			$ch = substr( $channel_text_copy, int( rand 18 ), 1 ) while $ch eq " ";
			my ($len) = 0;
			$len++ while( $channel_text_copy =~ s/\Q$ch\E//i );
			$spam_detected += $spam_penalty if( ( (length $channel_text) - $len) < 5 );

		$channel_text_copy = $channel_text;
		# ////// detect spams of the shift+number variety
		# like : @#^%(&@^*(@)!_#)^
			my ($strip_chars) = '!@#$%^&*()_+=-0987654321~`';
			$channel_text_copy =~ s/[\Q$strip_chars\E]//gi;
			$spam_detected += $spam_penalty if( length $channel_text_copy < 5 );

		$channel_text_copy = $channel_text;
		# ////// detect spams on the home row
		# like : ksajflk;afkasfhasjfhaslkjhfalsfhlh
			my ($strip_chars) = 'asdfghjkl;\'';
			$channel_text_copy =~ s/[\Q$strip_chars\E]//gi;
			$spam_detected += $spam_penalty if( length $channel_text_copy < 5 );
	}

	if( $spam_detected > 0 )
	{
		my ($len) = length $channel_text;
		$len *= $spam_detected;
		my ($newscore) = $len / $chars_per_point unless $chars_per_point < 1;
		my ($spam_detected_msg) = $sql->oneShot( qq~SELECT spam_detected FROM languages WHERE language_id=$language_id~ );
		my (%tokens) = (
			name => $nick,
			deduction => $newscore,
			plural => '' );
		$tokens{'plural'} = 's' if $newscore != 1;
		$self->privmsg( $channel_name, &miniLanguage($spam_detected_msg,%tokens) );
		$sql->ocQuery( qq~UPDATE users SET score=score-$len,linecount=linecount+1 WHERE username="$nick" AND bot_id=$bot_id~ );
	}
	else
	{
		my ($len) = length $channel_text;
		$sql->ocQuery( qq~UPDATE users SET score=score+$len,linecount=linecount+1 WHERE username="$nick" AND bot_id=$bot_id~ );

		if( $eliza == 1 )
		{
			if( $channel_text =~ m/^$bot_nickname:/i )
			{
				$channel_text =~ s/^$bot_nickname//i;
				my ($botsays) = $elizabot->transform( $channel_text );
				$self->privmsg( $channel_name, $botsays );
			}
		}
	}
}


###########################################################################
# Handles the valid commands for our bot
sub process_command()
{
	my ($self, $event, $command, @command_args) = @_;

	# Let's find out who is issuing the command
	# by checking in our handy dandy - notebook
	my ($nick) = ($event->nick);
	my ($channel_name) = ($event->to);

	# clean up the text (remove ; exploit for sql statements)
	$command =~ s/[^\Q$accepted_characters\E]//g;

	my (%tokens) = (
		name => $command_args[0],
		person => $nick,
		channel => $channel_name,
		plural => ''
	);

	my ($bot_nickname,$chars_per_point) = $sql->oneShot( qq~SELECT nickname,chars_per_point FROM bots WHERE bot_id=$bot_id~ );

	# let's just have a little fun if a user tries to perform some sort of lookup on the bot
	if( $command_args[0] eq $bot_nickname ){
		foreach( lc($command) ){
			if( /score/ || /rank/ ){
				my ($bot_selfscore_msg) = $sql->oneShot( qq~SELECT bot_selfscore FROM languages WHERE language_id=$language_id~ );
				$self->privmsg( $channel_name, &miniLanguage($bot_selfscore_msg,%tokens) );
			}
			elsif( /seen/ ){
				my ($bot_selfseen_msg) = $sql->oneShot( qq~SELECT bot_selfseen FROM languages WHERE language_id=$language_id~ );
				$self->privmsg( $channel_name, &miniLanguage($bot_selfseen_msg,%tokens) );
			}
		}return;
	}

	# process the commands we have programmed
	foreach( lc($command) )
	{
		if( /quote/ )
		{
			my ($quote_message) = &randomLine( "quotes" );	 # don't you wish all user-programmed
			$self->privmsg( $channel_name, $quote_message ); # functions were this easy ? 
		}
		elsif( /uptime/ )
		{
			# THANKS WOLFJOURN!!!!!!
			my ($uptime) = `uptime`;
			$uptime =~ s/^ *//g;
			$self->privmsg( $channel_name, $uptime );
		}
		elsif( /score/ )
		{
			my ($nick_to_score) = $nick;
			if( $command_args[0] ne "" ){ $nick_to_score = $command_args[0]; }

			my ($score_report_msg,$score_error_msg) = $sql->oneShot( qq~SELECT score_report,score_error FROM languages WHERE language_id=$language_id~ );

			# first we need to see if the person's name they requested is just someone that's on the channel right now
			my ($real_username,$score) = $sql->oneShot( qq~SELECT real_username,score FROM users WHERE LOWER(username)="$nick_to_score" AND bot_id=$bot_id~ );

			if( $real_username eq "" )
			{
				# the username they requested wasn't found, so perhaps they were requesting the score of the base username
				($real_username,$score) = $sql->oneShot( qq~SELECT real_username,score FROM users WHERE LOWER(real_username)="$nick_to_score" AND bot_id=$bot_id~ );

				if( $real_username eq "" )
				{
					# this user doesn't exist in the database
					$tokens{'name'} = $nick_to_score;
					$self->privmsg( $channel_name, &miniLanguage($score_error_msg,%tokens) );
					return;
				}
			}

			$tokens{'name'} = $real_username;
			$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
			$tokens{'plural'} = 's' if $tokens{'score'} != 1;
			$self->privmsg( $channel_name, &miniLanguage($score_report_msg,%tokens) );
		}
		elsif( /rank/ )	# an alternative to score, that lists what number you are in the rankings
		{
			my ($nick_to_score) = lc($nick);
			my ($rank_to_score) = "";

			my ($rank_report_msg,$rank_error_msg) = $sql->oneShot( qq~SELECT rank_report,rank_error FROM languages WHERE language_id=$language_id~ );

			if( $command_args[0] ne "" )
			{
				$rank_to_score = $command_args[0];

				if (( $rank_to_score =~ /(\d+)/) && (not($rank_to_score =~ /[a-zA-Z|\\`\[\]\{\}\(\)_\-]/)))
				{
					# they want the persons name associated with this number rank
					my ($rankcounter) = 0;
					my ($username,$real_username,$score);
					$sql->doQuery( qq~SELECT username,real_username,score FROM users WHERE bot_id=$bot_id ORDER BY score DESC~ );
					while( ($username,$real_username,$score) = $sql->getResults() )
					{
						$rankcounter++;
						last if $rankcounter == $rank_to_score;
					}
					$sql->finishQuery();

					if( $rankcounter < $rank_to_score )
					{
						# this user doesn't exist in the database
						$rank_error_msg =~ s/<rank>(.*?)<\/rank>//g;$rank_error_msg = $1;
						$tokens{'rank'} = $rank_to_score;
						$self->privmsg( $channel_name, &miniLanguage( $rank_error_msg, %tokens ) );
						return;
					}

					$tokens{'name'} = $real_username;
					$tokens{'rank'} = $rankcounter;
					$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
					$tokens{'plural'} = 's' if $tokens{'score'} != 1;
					$self->privmsg( $channel_name, &miniLanguage($rank_report_msg,%tokens) );
				}
				else
				{
					$nick_to_score = lc($command_args[0]);

					# first we need to see if the person's name they requested is just someone that's on the channel right now
					my ($real_username,$score) = $sql->oneShot( qq~SELECT real_username,score FROM users WHERE LOWER(username)="$nick_to_score" AND bot_id=$bot_id~ );

					if( $real_username eq "" )
					{
						# that user isn't on the channel, maybe they requested a base user rank
						($real_username,$score) = $sql->oneShot( qq~SELECT real_username,score FROM users WHERE LOWER(real_username)="$nick_to_score" AND bot_id=$bot_id~ );

						if( $real_username eq "" )
						{
							# this user doesn't exist in the database
							$rank_error_msg =~ s/<name>(.*?)<\/name>//g;$rank_error_msg = $1;
							$tokens{'name'} = $nick_to_score;
							$self->privmsg( $channel_name, &miniLanguage($rank_error_msg,%tokens) );
							return;
						}
						else
						{
							# we check against the real_username
							my ($rankcounter) = 0;
							my ($username,$real_username,$score);

							$sql->doQuery( qq~SELECT username,real_username,score FROM users WHERE bot_id=$bot_id ORDER BY score DESC~ );
							while( ($username,$real_username,$score) = $sql->getResults() )
							{
								$rankcounter++;
								last if lc($real_username) eq $nick_to_score;
							}
							$sql->finishQuery();

							$tokens{'name'} = $real_username;
							$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
							$tokens{'rank'} = $rankcounter;
							$tokens{'plural'} = 's' if $tokens{'score'} != 1;
							$self->privmsg( $channel_name, &miniLanguage($rank_report_msg,%tokens) );
						}
					}
					else
					{
						# the user is on the channel right now
						my ($rankcounter) = 0;
						my ($username,$real_username,$score);

						$sql->doQuery( qq~SELECT username,real_username,score FROM users WHERE bot_id=$bot_id ORDER BY score DESC~ );
						while( ($username,$real_username,$score) = $sql->getResults() )
						{
							$rankcounter++;
							last if lc($username) eq $nick_to_score;
						}
						$sql->finishQuery();

						$tokens{'name'} = $real_username;
						$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
						$tokens{'rank'} = $rankcounter;
						$tokens{'plural'} = 's' if $tokens{'score'} != 1;
						$self->privmsg( $channel_name, &miniLanguage($rank_report_msg,%tokens) );
					}
					
				}
			}
			else
			{
				my ($rankcounter) = 0;
				my ($username,$real_username,$score);

				$sql->doQuery( qq~SELECT username,real_username,score FROM users WHERE bot_id=$bot_id ORDER BY score DESC~ );
				while( ($username,$real_username,$score) = $sql->getResults() )
				{
					$rankcounter++;
					last if lc($username) eq $nick_to_score;
				}
				$sql->finishQuery();

				$tokens{'name'} = $real_username;
				$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
				$tokens{'rank'} = $rankcounter;
				$tokens{'plural'} = 's' if $tokens{'score'} != 1;
				$self->privmsg( $channel_name, &miniLanguage($rank_report_msg,%tokens) );
			}
		}
		elsif( /top10/ )
		{
			my ($score_top10_format) = $sql->oneShot( qq~SELECT score_top10 FROM languages WHERE language_id=$language_id~ );

			# most of what you see in this god-awful looking mess of regexes is a simple pretty-printing formula
			# that allows the config file to specify the output format for the bot	
			#
			my ($intro_text) = $score_top10_format;		# split out the intro text
			$intro_text =~ s/<intro>(.*?)<\/intro>//gi;$intro_text = $1;

			my ($outtro_text) = $score_top10_format;	# split out the outtro text
			$outtro_text =~ s/<outtro>(.*?)<\/outtro>//gi;$outtro_text = $1;

			my ($appending) = $score_top10_format;		# split out the notfinal parameter
			$appending =~ s/<notfinal>(.*?)<\/notfinal>//gi;$appending = $1;

			my ($final_msg) = $intro_text;			# start with the intro text

			$sql->doQuery( qq~SELECT real_username,score FROM users WHERE bot_id=$bot_id ORDER BY score DESC LIMIT 10~ );
			my ($curname,$score);
			while( ($curname,$score) = $sql->getResults() )
			{
				my ($currmsg) = $score_top10_format;
				$score = $score / $chars_per_point unless $chars_per_point < 1; # avoid people who think they're clever
												# by setting this negative or to 0
				$currmsg =~ s/<outtro>(.*?)<\/outtro>//gi;
				$currmsg =~ s/<intro>(.*?)<\/intro>//gi;
				$currmsg =~ s/<notfinal>(.*?)<\/notfinal>//gi;

				$tokens{'name'} = $curname;
				$tokens{'score'} = $score;
				$tokens{'plural'} = 's' if $score != 1;

				$currmsg = &miniLanguage( $currmsg, %tokens );

				$final_msg .= $currmsg . $appending;
			}
			$sql->finishQuery();

			chop $final_msg for( 1 .. length $appending );	# take off the last appending
			$final_msg .= $outtro_text;			# append the outtro

			$self->privmsg( $channel_name, $final_msg );
		}
		elsif( /addme/ )
		{
			my ($nickcopy) = lc($nick);

			my ($userid) = $sql->oneShot( qq~SELECT user_id FROM users WHERE LOWER(real_username)="$nickcopy" AND bot_id=$bot_id~ );

			# as long as this username doesn't exist, let's add them to our database
			if( $userid eq "" )
			{
				my ($newscore) = 0;
				$newscore = 50 * $chars_per_point if lc($command_args[0]) eq "please";

				$sql->ocQuery( qq~INSERT INTO users (user_id, username, real_username, score, ident, password, last_seen, active, enemy, flood, linecount, bot_id) VALUES(0,"$nick","$nick",$newscore,"NOTENABLEDYET","NOTENABLEDYET", NOW(), 1, 0, 0, 0, $bot_id)~ );

				my ($add_to_db_msg) = $sql->oneShot( qq~SELECT add_to_db FROM languages WHERE language_id=$language_id~ );
				$self->privmsg( $channel_name, &miniLanguage($add_to_db_msg, %tokens) );
				$self->privmsg( $channel_name, "And for being so polite I gave you 50 more points" ) if lc($command_args[0]) eq "please";
	
				$sql->ocQuery( qq~UPDATE users SET username=real_username WHERE username="$nick" AND bot_id=$bot_id~ );
			}
		}
		elsif( /seen/ )
		{
			my ($person) = $command_args[0];
			my ($smsg,$seendate,$active,$days,$hours,$minutes,$seconds);
			return if $person eq "";

			if( $person eq $nick )
			{
				($smsg) = $sql->oneShot( qq~SELECT seen_yourself FROM languages WHERE language_id=$language_id~ );
			}
			else
			{
				($seendate,$active) = $sql->oneShot( qq~SELECT ( UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(last_seen) ),active FROM users WHERE real_username="$person" AND bot_id=$bot_id~ );
				if ($seendate eq "" )
				{
					($smsg) = $sql->oneShot( qq~SELECT seen_notfound FROM languages WHERE language_id=$language_id~ );
				}
				elsif( $active == 1 )
				{
					($smsg) = $sql->oneShot( qq~SELECT seen_onchannel	 FROM languages WHERE language_id=$language_id~ );
				}
				else
				{
					($smsg) = $sql->oneShot( qq~SELECT seen_found FROM languages WHERE language_id=$language_id~ );
					$days = int($seendate / 86400);	$seendate = $seendate % 86400;
					$hours = int($seendate / 3600);	$seendate = $seendate % 3600;
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

			$self->privmsg( $channel_name, &miniLanguage( $smsg, %tokens ) );
		}
	}
}


###########################################################################
# handles private messages to the bot
sub on_msg
{
	my ($self, $event) = @_;
	my (@args) = ($event->args);
	my ($nick) = ($event->nick);
	my ($bot_nickname) = ($self->nick);

	if( not &flood_limit("priv",$nick) )
	{
		my ($channel,$des_salt,$control_password) = $sql->oneShot( qq~SELECT channel,des_salt,control_password FROM bots WHERE bot_id=$bot_id~ );

		my ($attempted_pw,$command,@command_args) = split( / /, $args[0] );
		my ($cpw) = crypt( $attempted_pw, $des_salt );
		my (%tokens) = ( person => $nick );

		if( $cpw eq $control_password )
		{
			foreach( $command )
			{
				if( /restart/ )
				{
					my ($restart_msg) = $sql->oneShot( qq~SELECT restart FROM languages WHERE language_id=$language_id~ );
	    				$self->quit( &miniLanguage($restart_msg,%tokens) );
	    				exec("perl $workingdir/$script_name");
				}
				elsif( /eliza/ )
				{
					my ($eliza_msg,$eliza) = $sql->oneShot( qq~SELECT languages.eliza,bots.eliza_mode FROM languages,bots WHERE languages.language_id=$language_id AND bots.bot_id=$bot_id~ );
					$eliza = ($eliza == 1 ? 0 : 1 );
					$tokens{'status'} = "on" if $eliza == 1;
					$tokens{'status'} = "off" if $eliza == 0;
					$sql->ocQuery( qq~UPDATE bots SET eliza_mode=$eliza WHERE bot_id=$bot_id~ );
					$self->privmsg( $channel, &miniLanguage( $eliza_msg, %tokens ) );
				}
				elsif( /advertise/ )
				{
					$self->privmsg( $channel, $version );
				}
				elsif( /reload_configuration/ )
				{
					# NOTE THAT THIS COMMAND IS UTTERLY USELESS NOW, lol
					my ($reload_config_msg) = $sql->oneShot( qq~SELECT reload_config FROM languages WHERE language_id=$language_id~ );
					$self->privmsg( $channel, &miniLanguage($reload_config_msg,%tokens) );
				}
				elsif( /op/ )
				{
					my ($person_to_op) = $command_args[0];
					$self->sl( "MODE $channel +o $person_to_op" );
				}
				elsif( /cycle/ )
				{
					my ($cycle_msg) = $sql->oneShot( qq~SELECT cycle FROM languages WHERE language_id=$language_id~ );
					$cycle_msg = &miniLanguage($cycle_msg, %tokens);
		    			$self->sl( "PART $channel $cycle_msg" );
	    				$self->sl( "JOIN $channel" );
				}
				elsif( /action/ )
				{
					my ($action_text) = join( ' ', @command_args );
					$self->ctcp("ACTION", $channel, $action_text);
				}
				elsif( /say/ )
				{
					my ($message) = join( ' ', @command_args );
	    				$self->privmsg( $channel, $message);
				}
				elsif( /kickban/ )
				{
					my ($person_to_kick) = @command_args;
					shift @command_args;
					my ($kick_msg) = join( ' ', @command_args );

					$kick_msg = &randomLine( "kick_messages" ) if( $kick_msg eq "random" );
					$self->sl("MODE $channel +b *${person_to_kick}!*@*");
					$self->kick( $channel, $person_to_kick, $kick_msg );
				}
				elsif( /kick/ )
				{
					my ($person_to_kick) = @command_args;
					shift @command_args;
					my ($kick_msg) = join( ' ', @command_args );

					$kick_msg = &randomLine( "kick_messages" ) if( $kick_msg eq "random" );
					$self->kick( $channel, $person_to_kick, $kick_msg );
	    			}
				elsif( /score/ )
				{
					my ($person,$sign,$amount) = @command_args;
					return if $person eq "";
					return if $sign eq "";
					return if $amount eq "";

					my ($chars_per_point) = $sql->oneShot( qq~SELECT chars_per_point FROM bots WHERE bot_id=$bot_id~ );

					$amount = $amount * $chars_per_point;
					return if $sign !~ m/^[+-]/;
					my ($increment) = join( '', $sign, $amount );
	
					my ($oldscore) = $sql->oneShot( qq~SELECT score FROM users WHERE real_username="$person" AND bot_id=$bot_id~ );
					return if $oldscore eq "";

					$sql->ocQuery( qq~UPDATE users SET score=score${increment} WHERE real_username="$person" AND bot_id=$bot_id~ );
					my ($newscore) = $oldscore + ( $sign eq "+" ? $amount : -$amount );

					$oldscore = $oldscore / $chars_per_point;
					$newscore = $newscore / $chars_per_point;
					$amount = $amount / $chars_per_point;
					$increment = join( '', $sign, $amount );

					my ($score_change_msg) = $sql->oneShot( qq~SELECT score_change FROM languages WHERE language_id=$language_id~ );
					$tokens{'person'} = $nick;
					$tokens{'channel'} = $channel;
					$tokens{'name'} = $person;	# as long as I know what i'm doing (don't confuse these two)
					$tokens{'oldscore'} = $oldscore;
					$tokens{'newscore'} = $newscore;
					$tokens{'increment'} = $increment;
					$self->privmsg( $channel, &miniLanguage($score_change_msg,%tokens) );
				}
				elsif( /language/ )
				{
					my ($language_changed_msg) = $sql->oneShot( qq~SELECT language_changed FROM languages WHERE language_id=$language_id~ );
					my ($language) = $command_args[0];
					&debug( "Got language request for $language" );

					$tokens{'oldlanguage'} = $sql->oneShot( qq~SELECT name FROM languages WHERE language_id=$language_id~ );
					$tokens{'newlanguage'} = $language;
					$language = lc($language);
					$language_id = $sql->oneShot( qq~SELECT language_id FROM languages WHERE LOWER(name)="$language"~ );
					return if($language_id eq "" );

					$self->privmsg( $channel, &miniLanguage( $language_changed_msg, %tokens ) );
				}
				elsif( /raw/ )
				{
					my ($rawcode) = join( ' ', @command_args);
					&debug( "Rawcode command: $rawcode" );
					$self->sl( $rawcode );
				}
				elsif( /help/ )
				{
					$self->privmsg( $nick, $version );
					$self->privmsg( $nick, "---------------------------" );
					$self->privmsg( $nick, "usage: /msg $bot_nickname <password> <command> [<args> ]" );
					$self->privmsg( $nick, "---------------------------" );
					$self->privmsg( $nick, "say <text> - makes the bot say that text in channel" );
					$self->privmsg( $nick, "action <text> - the bot does \"/me <text>\"" );
					$self->privmsg( $nick, "restart - starts the bots perl script over" );
					$self->privmsg( $nick, "advertise - displays the bots version number in each channel" );
					$self->privmsg( $nick, "kick <user> [<message>] - the bot kicks user from channel with alternate kick message (you can set this to \"random\" and the bot will pick one for you!" );
					$self->privmsg( $nick, "kickban <user> [<message>] - the bot bans and then kicks this user from channel with alternate kick message (you can set this to \"random\" and the bot will pick one for you!" );
					$self->privmsg( $nick, "cycle - makes the bot leave and rejoin the channel" );
					$self->privmsg( $nick, "op <user> - the bot will set +o on user in channel" );
					$self->privmsg( $nick, "reload_configuration - the bot will reload it's config (useless now)" );
					$self->privmsg( $nick, "score <user> <+/-> <amount> - the bot will change user's score by (+/-) amount" );
					$self->privmsg( $nick, "language <newlanguage> - the bot will change the language file to language_config.dat" );
					$self->privmsg( $nick, "eliza - toggles eliza mode" );
					$self->privmsg( $nick, "raw <rawcode> - sends rawcode message to server" );
					$self->privmsg( $nick, "help - yes, it is helpful isn't it?" );
				}
			}
		}
		else
		{
			&debug( "Invalid Authorization for ${nick}!!" );
		}
	}
}


###########################################################################
# Handles anything we want to understand ;)
sub on_rawcode
{
	print "------------------------------------\n";
	my ($self, $event) = @_;
	$event->dump;
}


###########################################################################
# helps prevent CTCP and message attacks
sub flood_limit
{
	my ($type,$nick) = @_;

	my ($use_flood_detection,$flood_ctcp_seconds,$flood_ctcp_lines,
	$flood_priv_seconds,$flood_priv_lines,$flood_public_lines,$flood_public_seconds)
	 = $sql->oneShot( qq~SELECT use_flood_detection,ctcp_flood_seconds,ctcp_flood_lines,private_flood_seconds,private_flood_lines,public_flood_lines,public_flood_seconds  FROM bots WHERE bot_id=$bot_id~ );

	return 0 if $use_flood_detection != 1;

	if( $type eq "ctcp" )
	{
		$sql->ocQuery( qq~INSERT INTO flood_check (username,type,time,bot_id) values( "$nick", "ctcp", NOW(), $bot_id )~ );
		$sql->doQuery( qq~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type="ctcp" AND bot_id=$bot_id AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < $flood_ctcp_seconds ORDER BY utime DESC~ );
		my ($counter) = 0;
		my ($time) = 0;
		$counter++ while( ($time) = $sql->getResults() );
		$sql->finishQuery();
		return ( $counter > $flood_ctcp_lines ? $counter : 0 );
	}
	elsif( $type eq "priv" )
	{
		$sql->ocQuery( qq~INSERT INTO flood_check (username,type,time,bot_id) values( "$nick", "priv", NOW(), $bot_id )~ );
		$sql->doQuery( qq~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type="priv" AND bot_id=$bot_id AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < $flood_priv_seconds ORDER BY utime DESC~ );
		my ($counter) = 0;
		my ($time) = 0;
		$counter++ while( ($time) = $sql->getResults() );
		$sql->finishQuery();
		return ( $counter > $flood_priv_lines ? $counter : 0 );
	}
	elsif( $type eq "public" )
	{
		$sql->ocQuery( qq~INSERT INTO flood_check (username,type,time,bot_id) values( "$nick", "public", NOW(), $bot_id )~ );
		$sql->doQuery( qq~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type="public" AND bot_id=$bot_id AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < $flood_public_seconds ORDER BY utime DESC~ );
		my ($counter) = 0;
		my ($time) = 0;
		$counter++ while( ($time) = $sql->getResults() );
		$sql->finishQuery();
		return ( $counter > $flood_public_lines ? $counter : 0 );
	}
}


###########################################################################
# my mini language processor thing for report messages
sub miniLanguage
{
	my ($message,%tokens) = @_;
	my ($tok) = "";
	foreach $tok ( keys( %tokens ) )
	{
		if( $tokens{$tok} !~ /\D/ )	# if the value of this is a number
		{
			# Break our message into <notzero> sized chunks
			my (@parts) = split ( /<notzero>/, $message );
			my ($counter) = 0;
			foreach(@parts){ $parts[$counter] = "<notzero>" . $parts[$counter] if $parts[$counter] =~ m/<\/notzero>/i; $counter++; }

			my ($insider);
			foreach $insider (@parts)
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
		else
		{
			# lets replace the token with it's value now
			$message =~ s/::${tok}::/$tokens{$tok}/gi;
		}
	}
	$message =~ s/<\/*b>/$font_style{'bold'}/gi;
	return $message;
}


###########################################################################
# loads the configuration file passed into $_[0]
# basically just sets a bunch of global variables (previously defined)
sub loadConfigurationFile()
{
	open( INF, $_[0] ) or &die_nice( "Error reading configuration file: $_[0]" );
	my( @config_lines ) = <INF>;
	chomp(@config_lines);
	close(INF);

	my($line);
	foreach $line ( @config_lines )
	{
		my ($line_check) = $line;
		$line_check =~ s/ //gi;
		if( $line_check ne "" && $line_check ne "\n" )
		{
			if( $line !~ m/^# / )
			{
				eval( $line );
			}
		}
	}

	print "Loaded configuration file: $_[0]\n" if $debug == 1;

	return 1;
}


###########################################################################
# outputs the string if debug == 1
sub debug(){
	print $_[0] . "\n" if $debug == 1;
}


###########################################################################
# Exits the program printing an error message specified by caller
sub die_nice()
{
	print "Unrecoverable error:\n";
	print $_[0] . "\n";
	exit;
}

###########################################################################
# program entry point
MAIN: {

	&loadConfigurationFile( "database.conf" );
	&loadConfigurationFile( "bot.conf" );
	
	# connect the SQL database
	$sql->connectDB( $db_name, $db_user, $db_pass );

	########################
	# get the bot's language/name
	my ($bot_nickname);
	$sql->doQuery( qq~SELECT language_id,nickname FROM bots WHERE bot_id=$bot_id~ );
	($language_id,$bot_nickname) = $sql->getResults();
	$sql->finishQuery();

	########################
	# if we are not running the same process, make sure the old one is dead 
	$sql->doQuery( qq~SELECT process_id FROM bots WHERE bot_id=$bot_id~ );
	my ($killpid) = $sql->getResults();
	$sql->finishQuery();

	#Gets current process
	my ($pid) = $$;

	#Kill last process
	&debug( "Current pid: $pid\tOld pid: $killpid" );
	if ( $killpid != $pid ) {
		&debug( "Killing last process" );
		kill( 9, $killpid );
	}

	# update with the new pid
	$sql->doQuery( qq~UPDATE bots SET process_id=$pid WHERE bot_id=$bot_id~ );
	########################

	########################
	# Eliza bot inits
	&debug( "Initializing Eliza Chat Interface" );
	rand( time ^ ($$ + ($$ << 15)) );
	$elizabot = new Chatbot::Eliza "$bot_nickname";
	########################

	########################
	# Set up our IRC connection
	$sql->doQuery( qq~SELECT server_name,server_port,nickname FROM bots WHERE bot_id=$bot_id~ );
	my ($server,$port,$nickname) = $sql->getResults();
	$sql->finishQuery();

	&debug( "Connecting to $server:$port" );

	$irc_server_connection = $irc_module->newconn
	(
		Server   => $server,
		Port     => $port,
		Nick     => $nickname,
		Ircname  => 'http://www.l8nite.net  &  http://www.slyfx.com',
		Username => $nickname
	) or &die_nice("Failed to make connection to irc server");

	# Set up our message hooks

		# when we connect to the server
		$irc_server_connection->add_global_handler('376', \&on_connect);

		# some housekeeping for initial irc connection messages 
		$irc_server_connection->add_global_handler([ 251,252,253,254,302,255 ], \&on_init);

		# handle version requests
		$irc_server_connection->add_handler('cversion',  \&on_version);

		# handle ping requests
		$irc_server_connection->add_handler('cping', \&on_ping);

		# what happens if someone gets kicked ?
		$irc_server_connection->add_handler('kick', \&on_kick);

		# what do we do when someone joins the room ?
		$irc_server_connection->add_handler('join', \&on_join);

		# what to do if we are banned
		$irc_server_connection->add_global_handler( '474', \&banned);

		# what should we do if someone else is using our nickname
		$irc_server_connection->add_global_handler( '433', \&on_nick_taken );

		# when we recieve channel text
		$irc_server_connection->add_handler('public', \&on_public);

		# list names in channel 
		$irc_server_connection->add_global_handler([ 353, 366 ], \&on_names);

		# when someone changes their nickname
		$irc_server_connection->add_handler('nick',   \&on_nick);

		# private message to the bot
		$irc_server_connection->add_handler('msg', \&on_msg);

		# when someone leaves the channel
		$irc_server_connection->add_handler('part',   \&on_part);

		# when someone leaves the server
		$irc_server_connection->add_handler('quit',   \&on_quit);

		# what to do if we get disconnected
		$irc_server_connection->add_global_handler('disconnect', \&on_disconnect);

	#Connect
	$irc_module->start;
	########################

	exit;
}

