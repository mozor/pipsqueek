#!/usr/bin/perl

#
#	PipSqueek [version 1.1.41-mysql]
#	© 2001 slyfx [slyfx@slyfx.com] & l8nite [l8nite@l8nite.net]
#	Shouts to trapper for the original ideas present in his subordinate bot
#	Shouts to Wolfjourn for solving a bug in the mysql database with the !seen code
#
#	Thanks to sub_pop_culture, Aleph, lordjasper, crazyhorse, Wolfjourn, and slyfx for
#	all your help beta testing and improving.
#
# 	TODO:
#	1 - eliza interface
#	2 - make the bot do something random when idle
#
#

#Modules
use strict;
push(@INC, ".");
use Net::IRC;	# for IRC connection
use DBI;	# for mysql

####### @@@@@@@ ####### @@@@@@@ ####### @@@@@@@ ####### @@@@@@@ ####### @@@@@@@ #######
# this should be the only thing you have to change as a user
my ($language) = "american";
####### @@@@@@@ ####### @@@@@@@ ####### @@@@@@@ ####### @@@@@@@ ####### @@@@@@@ #######

# this is where all the configuration will be provided from
my ($config_file) = "${language}_config.dat";

# User-Definable ( in $config_file )
my(
	$debug,			# debug variable
	$server,		# server to connect to
	$port,			# port for this server
	$workingdir,		# home directory
	$control_password,	# author password, des encrypted
	$des_salt,		# des salt
	$bot_nickname,		# bot's nickname
	$bot_nickserv_password, # bot's nickserv password
	$bot_vhost_name,	# the vhost username
	$bot_vhost_pass,	# the vhost password
	$bot_channel_list,	# channels for bot to idle in
	$greet_msg,		# what the bot says to people joining
	$quotes_file,		# random quotes file for humor
	$kickmsg_file,		# random kick messages datafile
	$script_name,		# the bots actual script name
	$pid_log,		# so we can kill our old processes
	$swap_file,		# to keep track of nickname changes
	$command_prefix,	# type as first character for bot command
	$valid_commands,	# the valid commands for this bot
	$command_delay,		# how many seconds in between each command request
	$chars_per_point,	# how many chars a person says per point
	$spam_penalty,		# factor for penalizing flooders
	$use_spam_detection,	# self-explaining toggle
	$flood_ctcp_seconds,	# number of seconds before flood in ctcp
	$flood_priv_seconds,	# number of seconds before flood in private msg
	$flood_ctcp_lines,	# number of lines allowed before flood in ctcp 
	$flood_priv_lines,	# number of lines allowed before flood in private msg
	$flood_public_lines,	# number of lines before public chat flood
	$flood_public_seconds,	# number of seconds before public chat flood
	$use_flood_detection,	# self-explaining toggle
	$flood_penalty,		# how many points are deducted when bot detects a flood
	$score_report_msg,	# what the bot says when reporting scores
	$score_error_msg,	# what the bot says on not finding score
	$rank_report_msg,	# what the bot says when reporting ranks
	$rank_error_msg,	# what the bot says on not finding rank
	$score_top10_format,	# how the top10 line is formatted
	$add_to_db_msg,		# what the bot says on !addme
	$command_delay_msg,	# what the bot says when it notices a user for command delay
	$spam_detected_msg,	# what the bot says when it detects a flood
	$flood_detected_msg,	# what the bot says on point reduction for flooding
	$restart_msg,		# what the bot says on admin restart
	$reload_config_msg,	# what the bot says on admin reload of config
	$cycle_msg,		# what the bot says when it cycles the channel
	$score_change_msg,	# the report message when an admin changes a score
	$seen_found_msg,	# bot reports when finding a user in seen db
	$seen_notfound_msg,	# bot reports when it hasn't seen user
	$seen_yourself_msg,	# what the bot says when a user tries to find himself
	$seen_onchannel_msg,	# if the user is currently on the channel
	$bot_selfscore_msg,	# what the bot says when someone tries to rank or score it
	$bot_selfseen_msg,	# what the bot says when someone tries to find it.
	$language_changed_msg	# message you get when an admin changes the bot's language
);

# Bot-globals
my (%font_style) = (
	bold	=>	chr(0x02),
);

my ($version) = "PipSqueek [version 1.1.41-mysql]";
my ($accepted_characters) = ' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890~!@#$%^&*()_+`- =[]{}:<>,.?/|';
my ($command_characters) = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
my ($irc_module) = new Net::IRC;
my ($irc_server_connection);
my ($last_command_time);
my ($command_flood_toggle) = 0;
my ($dbh) = "";		# This is a handle to the database object
my ($query) = "";	# This is a handle to the results of a query
my ($query2) = "";	# A second results handle (for nested sql)


###########################################################################
####        The main function is at the bottom of the script =)        ####
###########################################################################

###########################################################################
# loads the configuration file passed into $_[0]
# expects the config file to be in the same directory as the bot and the
# perl script has to have defined the appropriate variables.
sub loadConfigurationFile()
{
	open( INF, $_[0] ) or &die_nice( "Error reading configuration file: $_[0]" );
	my (@config_lines) = <INF>;
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

	&debug( "Loaded configuration file: $_[0]\n" );

	return 1;
}


###########################################################################
# Returns a random line from the specified file
sub randomLine()
{
	print "Retrieving a random line from: $_[0]\n" if $debug == 1;
	open(INF, $_[0] ) or &die_nice( "Error reading from random line file: $_[0]" );
	my($line);
	srand;
	rand($.) < 1 && ($line = $_) while <INF>;
	close(INF);

	return $line;
}


###########################################################################
# outputs the string if debug == 1
sub debug(){
	print $_[0] . "\n" if $debug == 1;
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
# helps prevent CTCP and message attacks
sub flood_limit
{
	my ($type,$nick,$channel) = @_;

	return 0 if $use_flood_detection != 1;

	if( $type eq "ctcp" )
	{
		&doQuery( qq~INSERT INTO flood_check (type,time) values( "ctcp", NOW() )~ );
		&doQuery( qq~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type="ctcp" AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < $flood_ctcp_seconds ORDER BY utime DESC~ );
		my ($counter) = 0;
		my ($time) = 0;
		$counter++ while( ($time) = $query->fetchrow_array() );
		return ( $counter > $flood_ctcp_lines ? $counter : 0 );
	}
	elsif( $type eq "priv" )
	{
		&doQuery( qq~INSERT INTO flood_check (type,time) values( "priv", NOW() )~ );
		&doQuery( qq~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type="priv" AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < $flood_priv_seconds ORDER BY utime DESC~ );
		my ($counter) = 0;
		my ($time) = 0;
		$counter++ while( ($time) = $query->fetchrow_array() );
		return ( $counter > $flood_priv_lines ? $counter : 0 );
	}
	elsif( $type eq "public" )
	{
		&doQuery( qq~INSERT INTO flood_check (type,channel,time,username) values("public","$channel",NOW(),"$nick")~ );
		&doQuery( qq~SELECT UNIX_TIMESTAMP(time) as utime FROM flood_check WHERE type="public" AND channel="$channel" AND username="$nick" AND UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(time) < $flood_public_seconds ORDER BY utime DESC~ );
		my ($counter) = 0;
		my ($time) = 0;
		$counter++ while( ($time) = $query->fetchrow_array() );
		return ( $counter > $flood_public_lines ? $counter : 0 );
	}
}


###########################################################################
# What to do when the bot successfully connects.
sub on_connect
{
	my ($self, $event) = @_;

	&doQuery( qq~UPDATE users SET active=0~ );

	&debug( "Joining channels: $bot_channel_list" );

	# we need commas for the join command, but the config files
	# use spaces (just a design issue really)
	my ($botchanlist) = $bot_channel_list;
	$botchanlist =~ s/ /,/g;

	# Tell the server that this is a bot
	$self->sl("MODE $bot_nickname +B");

	# Message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $bot_nickserv_password");

	# Set ourselves up with the vhost
	if( $bot_vhost_name ne "" ){
		$self->sl("VHOST $bot_vhost_name $bot_vhost_pass");
	}

	# Join our channels
	$self->join( $botchanlist );
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
	if( not &flood_limit("ctcp") )
	{
		my ($self, $event) = @_;
		my $nick = $event->nick;
		&debug( "Received CTCP VERSION request from $nick" );
		$self->ctcp_reply($nick, $version);
	}
}


###########################################################################
# CTCP Ping reply
sub on_ping
{
	if( not &flood_limit("ctcp") )
	{
		my ($self, $event) = @_;
		my ($nick) = $event->nick;
		my ($arg) = ($event->args);
		&debug( "Received CTCP PING request from $nick" );
		$self->ctcp_reply($nick, "PONG! $arg");
	}
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
# Someone has joined, what should we do ?
sub on_join
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($channel_name) = ($event->to);

	# strip out the operator status symbol
	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);

	&debug( "$nick joined channel $channel_name" );

	# tell our database that this user is active in the channel now, but only if this user is actually
	# in our database as a real_username (meaning they have used !addme )
	&doQuery( qq~UPDATE users SET active=1,username=real_username WHERE real_username="$nick" AND channel="$channel_name"~ );

	`sleep 1`;

	my ($greeting) = $greet_msg;
	$greeting =~ s/::name::/$nick/g;

	# If it was us that joined the channel, we need to get revenge on anyone that may have kicked us
	if( $nick eq $bot_nickname )
	{
		&doQuery( qq~SELECT username FROM users WHERE enemy=1 AND channel="$channel_name"~ );
		my ($tokick);
		while( $tokick = $query->fetchrow_array() )
		{
			my ($kick_message) = &randomLine( $kickmsg_file );
			$self->kick( $channel_name, $tokick, $kick_message );
		}
		&doQuery( qq~UPDATE users SET enemy=0 WHERE enemy=1 AND channel="$channel_name"~ );
	}
	else
	{
		$self->privmsg($channel_name, $greeting) unless $greet_msg eq "";
	}
}


###########################################################################
# Someone has left a channel
sub on_part
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($channel_name) = $event->to;

	# strip out the operator status symbol
	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);

	&debug( "$nick has left channel $channel_name" );

	# tell the database that the user is no longer active in this channel
	&doQuery( qq~UPDATE users SET active=0,last_seen=NOW() WHERE username="$nick" AND channel="$channel_name"~ );
}


###########################################################################
# Someone has left the server
sub on_quit
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;

	# strip out the operator status symbol
	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);

	&debug( "$nick has quit the irc server" );

	# since quitting the server isn't channel-related we need to update every channel
	&doQuery( qq~UPDATE users SET active=0,last_seen=NOW() WHERE username="$nick"~ );
}


###########################################################################
# On nickname change
sub on_nick
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($new_nick) = ($event->args);

	# strip out the operator status symbol
	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);

	&debug( "$nick has changed handles to $new_nick" );

	&doQuery( qq~SELECT userid FROM users WHERE real_username="$new_nick"~ );
	my ($userid) = $query->fetchrow_array();
	if( $userid eq "" )
	{	# they're just changing names
		&doQuery( qq~UPDATE users SET username="$new_nick" WHERE username="$nick"~ );
	}
	else
	{	# they're changing into someone else's base-name (identifying)

		# reset this user
		&doQuery( qq~UPDATE users SET username=real_username,active=0 WHERE username="$nick"~ );

		# reset the user they changed into
		&doQuery( qq~UPDATE users SET username=real_username,active=1 WHERE userid=$userid~ );
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

	if ( $person_kicked eq $bot_nickname )
	{
		&doQuery( qq~UPDATE users SET enemy=1 WHERE username="$the_kicker" AND channel="$channel_name"~ );
		$self->join($channel_name);
	}
	else
	{
		# they left the room technically, so tell the database that the user is no longer active in this channel
		&doQuery( qq~UPDATE users SET active=0 WHERE username="$person_kicked" AND channel="$channel_name"~ );
	}
}


###########################################################################
# If we are banned
sub banned
{
	my ($self, $event) = @_;
	my ($dummy,$channel_name) = ($event->args);

	&debug( "I was banned from $channel_name, unbanning." );

	# let's make sure we are who we want to be first
	$self->sl("NICK $bot_nickname");

	# message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $bot_nickserv_password");

	# make chanserv unban us
	$self->privmsg("ChanServ", "UNBAN $channel_name");

	$self->join( $channel_name );
}


###########################################################################
# If someone is using our nickname
sub on_nick_taken
{
	my ($self, $event) = @_;

	&debug( "Nickname $bot_nickname was taken, attempting to ghost\n" );

	$self->sl("NICK b1shKill3r2X");
	$self->privmsg("NickServ", "GHOST $bot_nickname $bot_nickserv_password");
	$self->sl("NICK $bot_nickname");

	# Message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $bot_nickserv_password");

	# Tell the server that this is a bot
	$self->sl("MODE $bot_nickname +B");

	# Set ourselves up with the vhost
	if( $bot_vhost_name ne "" ){
		$self->sl("VHOST $bot_vhost_name $bot_vhost_pass");
	}
}


###########################################################################
# What to do when we receive channel text.
sub on_public
{
	my ($self, $event) = @_;
	my ($nick) = ($event->nick);
	my ($channel_name) = ($event->to);

	my ($flood_amt) = &flood_limit( "public", $nick, $channel_name );
	
	if( $flood_amt == 0 || $use_flood_detection != 1 )
	{
		if( $use_flood_detection == 1 )
		{
			&doQuery( qq~SELECT flood FROM users WHERE username="$nick" AND channel="$channel_name"~ );
			$flood_amt = $query->fetchrow_array();
			if( $flood_amt != 0 )
			{
				my ($deduction) = $flood_amt * $flood_penalty;
				my ($newscore) = $deduction / $chars_per_point unless $chars_per_point < 1;
				my ($fmsg) = $flood_detected_msg;
				my (%tokens) = (
					name => $nick,
					deduction => $newscore,
					plural => '' );
					$tokens{'plural'} = 's' if $newscore != 1;
				$self->privmsg( $channel_name, &miniLanguage($fmsg,%tokens) );
				&doQuery( qq~UPDATE users SET flood=0,score=score-$deduction WHERE username="$nick" AND channel="$channel_name"~ );
			}
		}


		my ($channel_text) = ($event->args);

		# Output the text if debug = 2 ( chat-logging mode )
		print "<$nick> $channel_text\n" if $debug == 2;

		# Find out if this is a command
		if( substr( $channel_text, 0, 1 ) eq $command_prefix )
		{
			# The first character was a command prefix, now make sure it's not been disabled by our config file
			my (@temp) = split( / /, $channel_text );
			my ($len) = length $temp[0];
			my ($command) = substr( $temp[0], 1, $len - 1 );
			my (@command_args) = @temp;
			shift @command_args; # get rid of the command part

			my ($vclist) = $valid_commands;

		#watchtower was here.
		# <Project1> yum, perl
		# <Project1> ick, 
		# * Project1 spits it out
		# <Project1> larry wall tastes like shit
		# <Wolfjourn> perl is like that hoe you see on the street corner.. only looks good when you're not getting it

			# Clean up the command text
			$command =~ s/[^\Q$command_characters\E]//g;

			my ($seconds) = (time - $last_command_time);
			if( $seconds < $command_delay )
			{
				if( $command_flood_toggle == 0 )
				{
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
			else
			{
				$command_flood_toggle = 0;
			}

			if(  $vclist =~ m/\Q$command\E/gi && $command ne "" ){
				&process_command( $self, $event, $command, @command_args );
				$last_command_time = time;
			}
			else{
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
		&doQuery( qq~UPDATE users SET flood=flood+$flood_amt WHERE username="$nick" AND channel="$channel_name"~ );
	}
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
		&doQuery( qq~UPDATE users SET active=1 WHERE (username=$namelist) AND (channel="$channel_name")~ );
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
		my ($fmsg) = $spam_detected_msg;
		my (%tokens) = (
			name => $nick,
			deduction => $newscore,
			plural => '' );
		$tokens{'plural'} = 's' if $newscore != 1;
		$self->privmsg( $channel_name, &miniLanguage($fmsg,%tokens) );
		&doQuery( qq~UPDATE users SET score=score-$len WHERE username="$nick" AND channel="$channel_name"~ );
	}
	else
	{
		my ($len) = length $channel_text;
		&doQuery( qq~UPDATE users SET score=score+$len WHERE username="$nick" AND channel="$channel_name"~ );
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

	# let's just have a little fun if a user tries to perform some sort of lookup on the bot
	if( $command_args[0] eq $bot_nickname ){
		foreach( lc($command) ){
			if( /score/ || /rank/ ){
				$self->privmsg( $channel_name, $bot_selfscore_msg );
			}
			elsif( /seen/ ){
				$self->privmsg( $channel_name, $bot_selfseen_msg );
			}
		}return;
	}

	# process the commands we have programmed
	foreach( lc($command) )
	{
		if( /quote/ )
		{
			my ($quote_message) = &randomLine( $quotes_file );	# don't you wish all user-programmed
			$self->privmsg( $channel_name, $quote_message );	# functions were this easy ? 
		}
		elsif( /uptime/ )
		{
			# THANKS WOLFJOURN!!!!!!
			my ($uptime) = `uptime`;
			$uptime =~ s/^ //g;
			$self->privmsg( $channel_name, $uptime );
		}
		elsif( /score/ )
		{
			my ($nick_to_score) = $nick;
			if( $command_args[0] ne "" ){ $nick_to_score = $command_args[0]; }

			my ($smsg) = $score_report_msg;
			my ($emsg) = $score_error_msg;

			# first we need to see if the person's name they requested is just someone that's on the channel right now
			&doQuery( qq~SELECT real_username,score FROM users WHERE LOWER(username)="$nick_to_score" AND channel="$channel_name"~ );
			my ($real_username,$score) = $query->fetchrow_array();

			if( $real_username eq "" )
			{
				# the username they requested wasn't found, so perhaps they were requesting the score of the base username
				&doQuery( qq~SELECT real_username,score FROM users WHERE LOWER(real_username)="$nick_to_score" AND channel="$channel_name"~ );
				($real_username,$score) = $query->fetchrow_array();

				if( $real_username eq "" )
				{
					# this user doesn't exist in the database
					$tokens{'name'} = $nick_to_score;
					$self->privmsg( $channel_name, &miniLanguage($emsg,%tokens) );
					return;
				}
			}

			$tokens{'name'} = $real_username;
			$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
			$tokens{'plural'} = 's' if $tokens{'score'} != 1;
			$self->privmsg( $channel_name, &miniLanguage($smsg,%tokens) );
		}
		elsif( /rank/ )	# an alternative to score, that lists what number you are in the rankings
		{
			my ($nick_to_score) = lc($nick);
			my ($rank_to_score) = "";

			my ($smsg) = $rank_report_msg;
			my ($emsg) = $rank_error_msg;

			if( $command_args[0] ne "" )
			{
				$rank_to_score = $command_args[0];

				if (( $rank_to_score =~ /(\d+)/) && (not($rank_to_score =~ /[a-zA-Z|`\[\]\{\}\(\)_\-]/)))
				{
					# they want the persons name associated with this number rank
					my ($rankcounter) = 0;
					my ($username,$real_username,$score);
					&doQuery( qq~SELECT username,real_username,score FROM users WHERE channel="$channel_name" ORDER BY score DESC~ );
					while( ($username,$real_username,$score) = $query->fetchrow_array() )
					{
						$rankcounter++;
						last if $rankcounter == $rank_to_score;
					}

					if( $rankcounter < $rank_to_score )
					{
						# this user doesn't exist in the database
						$emsg =~ s/<rank>(.*?)<\/rank>//g;$emsg = $1;
						$tokens{'rank'} = $rank_to_score;
						$self->privmsg( $channel_name, &miniLanguage( $emsg, %tokens ) );
						return;
					}

					$tokens{'name'} = $real_username;
					$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
					$tokens{'plural'} = 's' if $tokens{'score'} != 1;
					$self->privmsg( $channel_name, &miniLanguage($smsg,%tokens) );
				}
				else
				{
					$nick_to_score = lc($command_args[0]);
					# first we need to see if the person's name they requested is just someone that's on the channel right now
					&doQuery( qq~SELECT real_username,score FROM users WHERE LOWER(username)="$nick_to_score" AND channel="$channel_name"~ );
					my ($real_username,$score) = $query->fetchrow_array();
					if( $real_username eq "" )
					{
						# that user isn't on the channel, maybe they requested a base user rank
						&doQuery( qq~SELECT real_username,score FROM users WHERE LOWER(real_username)="$nick_to_score" AND channel="$channel_name"~ );
						($real_username,$score) = $query->fetchrow_array();

						if( $real_username eq "" )
						{
							# this user doesn't exist in the database
							$emsg =~ s/<name>(.*?)<\/name>//g;$emsg = $1;
							$tokens{'name'} = $nick_to_score;
							$self->privmsg( $channel_name, &miniLanguage($emsg,%tokens) );

							return;
						}
						else
						{
							# we check against the real_username
							my ($rankcounter) = 0;
							my ($username,$real_username,$score);
							&doQuery( qq~SELECT username,real_username,score FROM users WHERE channel="$channel_name" ORDER BY score DESC~ );

							while( ($username,$real_username,$score) = $query->fetchrow_array() )	{
								$rankcounter++;
								last if lc($real_username) eq $nick_to_score;
							}

							$tokens{'name'} = $real_username;
							$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
							$tokens{'rank'} = $rankcounter;
							$tokens{'plural'} = 's' if $tokens{'score'} != 1;
							$self->privmsg( $channel_name, &miniLanguage($smsg,%tokens) );
						}
					}
					else
					{
						# the user is on the channel right now
						my ($rankcounter) = 0;
						my ($username,$real_username,$score);
						&doQuery( qq~SELECT username,real_username,score FROM users WHERE channel="$channel_name" ORDER BY score DESC~ );

						while( ($username,$real_username,$score) = $query->fetchrow_array() )	{
							$rankcounter++;
							last if lc($username) eq $nick_to_score;
						}

						$tokens{'name'} = $real_username;
						$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
						$tokens{'rank'} = $rankcounter;
						$tokens{'plural'} = 's' if $tokens{'score'} != 1;
						$self->privmsg( $channel_name, &miniLanguage($smsg,%tokens) );
					}
					
				}
			}
			else
			{
				my ($rankcounter) = 0;
				my ($username,$real_username,$score);
				&doQuery( qq~SELECT username,real_username,score FROM users WHERE channel="$channel_name" ORDER BY score DESC~ );

				while( ($username,$real_username,$score) = $query->fetchrow_array() )	{
					$rankcounter++;
					last if lc($username) eq $nick_to_score;
				}

				$tokens{'name'} = $real_username;
				$tokens{'score'} = $score / $chars_per_point unless $chars_per_point < 1;
				$tokens{'rank'} = $rankcounter;
				$tokens{'plural'} = 's' if $tokens{'score'} != 1;
				$self->privmsg( $channel_name, &miniLanguage($smsg,%tokens) );
			}
		}
		elsif( /top10/ )
		{
			#
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

			&doQuery( qq~SELECT real_username,score FROM users WHERE channel="$channel_name" ORDER BY score DESC LIMIT 10~ );

			my ($curname,$score);
			while( ($curname,$score) = $query->fetchrow_array() )
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
			chop $final_msg for( 1 .. length $appending );	# take off the last appending
			$final_msg .= $outtro_text;			# append the outtro

			$self->privmsg( $channel_name, $final_msg );
		}
		elsif( /addme/ )
		{
			my ($nickcopy) = lc($nick);
			&doQuery( qq~SELECT userid FROM users WHERE LOWER(real_username)="$nickcopy" AND channel="$channel_name"~ );
			my ($userid) = $query->fetchrow_array();

			# as long as this username doesn't exist, let's add them to our database
			if( $userid eq "" )
			{
				my ($newscore) = 0;
				$newscore = 50 * $chars_per_point if lc($command_args[0]) eq "please";

				&doQuery( qq~INSERT INTO users (username, real_username, score, ident, last_seen, channel, active, enemy) VALUES("$nick","$nick",$newscore,"NOTENABLEDYET",NOW(),"$channel_name",1,0 )~ );
				my ($wmsg) = &miniLanguage($add_to_db_msg, %tokens);
				$self->privmsg( $channel_name, $wmsg );
				$self->privmsg( $channel_name, "And for being so polite I gave you 50 more points" ) if lc($command_args[0]) eq "please";
	
				&doQuery( qq~UPDATE users SET username=real_username WHERE username="$nick"~ );
			}
		}
		elsif( /seen/ )
		{
			my ($person) = $command_args[0];
			my ($smsg,$seendate,$active,$days,$hours,$minutes,$seconds);
			return if $person eq "";

			if( $person eq $nick ){ $smsg = $seen_yourself_msg; }
			else{
				&doQuery( qq~SELECT ( UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(last_seen) ),active FROM users WHERE real_username="$person" AND channel="$channel_name"~ );
				($seendate,$active) = $query->fetchrow_array();
				if ($seendate eq "" ){ $smsg = $seen_notfound_msg; }
				elsif( $active == 1 ){ $smsg = $seen_onchannel_msg; }
				else{
					$smsg = $seen_found_msg;
					$days = int($seendate / 86400);	$seendate = $seendate % 86400;
					$hours = int($seendate / 3600);	$seendate = $seendate % 3600;
					$minutes = int($seendate / 60); $seendate = $seendate % 60;
					$seconds = $seendate;
				}
			}

			$tokens{'days'} = $days;
			$tokens{'hours'} = $hours;
			$tokens{'minutes'} = $minutes;
			$tokens{'seconds'} = $seconds;
			$smsg = &miniLanguage( $smsg, %tokens );
			$self->privmsg( $channel_name, $smsg );
		}
	}
}


###########################################################################
# handles private messages to the bot
sub on_msg
{
	if( not &flood_limit("priv") )
	{
	my ($self, $event) = @_;
	my (@args) = ($event->args);
	my ($nick) = ($event->nick);

	my ($attempted_pw,$command,@command_args) = split( / /, $args[0] );

	my ($cpw) = crypt( $attempted_pw, $des_salt );

	my (%tokens) = ( person => $nick );

	if( $cpw eq $control_password )
	{
		foreach( $command )
		{
			if( /restart/ )
			{
				my ($qmsg) = $restart_msg;
	    			$self->quit( &miniLanguage($qmsg,%tokens) );
	    			exec("perl $workingdir/$script_name");
			}
			elsif( /advertise/ )
			{
				my (@channels) = split( / /, $bot_channel_list );
				my ($channel) = "";
				foreach $channel (@channels)
				{
					$self->privmsg( $channel, $version );
				}
			}
			elsif( /reload_configuration/ )
			{
				my (@channels) = split( / /, $bot_channel_list );
				my ($channel) = "";
				my ($rcfgmsg) = $reload_config_msg;

				foreach $channel (@channels)
				{
					$self->privmsg( $channel, &miniLanguage($rcfgmsg,%tokens) );
				}
				# load the configuration file
				&loadConfigurationFile( $config_file );
			}
			elsif( /op/ )
			{
				my ($channel_to_op_on) = $command_args[0];
				my ($person_to_op) = $command_args[1];
				$self->sl( "MODE $channel_to_op_on +o $person_to_op" );
			}
			elsif( /cycle/ )
			{
				my ($channel_to_cycle) = $command_args[0];
	    			$self->sl( "PART $channel_to_cycle $cycle_msg" );
	    			$self->sl( "JOIN $channel_to_cycle" );
			}
			elsif( /action/ )
			{
				my ($channel_name) = $command_args[0];
				shift @command_args;
				my ($action_text) = join( ' ', @command_args );
				$self->ctcp("ACTION", $channel_name, $action_text);
			}
			elsif( /say/ )
			{
				my ($channel_name) = $command_args[0];
				shift @command_args;
				my ($message) = join( ' ', @command_args );
	    			$self->privmsg( $channel_name, $message);
			}
			elsif( /kickban/ )
			{
				my ($channel_name,$person_to_kick) = @command_args;
				shift @command_args; shift @command_args;
				my ($kick_msg) = join( ' ', @command_args );

				$kick_msg = &randomLine( $kickmsg_file ) if( $kick_msg eq "random" );
				$self->sl("MODE $channel_name +b *${person_to_kick}!*@*");
				$self->kick( $channel_name, $person_to_kick, $kick_msg );
			}
			elsif( /kick/ )
			{
				my ($channel_name,$person_to_kick) = @command_args;
				shift @command_args; shift @command_args;
				my ($kick_msg) = join( ' ', @command_args );

				$kick_msg = &randomLine( $kickmsg_file ) if( $kick_msg eq "random" );
				$self->kick( $channel_name, $person_to_kick, $kick_msg );
	    		}
			elsif( /score/ )
			{
				my ($channel_name,$person,$sign,$amount) = @command_args;
				return if $channel_name eq "";

				$amount = $amount * $chars_per_point;
				return if $sign !~ m/^[+-]/;
				my ($increment) = join( '', $sign, $amount );

				&doQuery( qq~SELECT score FROM users WHERE real_username="$person" AND channel="$channel_name"~ );
				my ($oldscore) = $query->fetchrow_array();
				return if $oldscore eq "";

				&doQuery( qq~UPDATE users SET score=score${increment} WHERE real_username="$person" AND channel="$channel_name"~ );
				my ($newscore) = $oldscore + ( $sign eq "+" ? $amount : -$amount );

				$oldscore = $oldscore / $chars_per_point;
				$newscore = $newscore / $chars_per_point;
				$amount = $amount / $chars_per_point;
				$increment = join( '', $sign, $amount );

				my ($smsg) = $score_change_msg;
				$tokens{'person'} = $nick;
				$tokens{'channel'} = $channel_name;
				$tokens{'name'} = $person;	# as long as I know what i'm doing (don't confuse these two)
				$tokens{'oldscore'} = $oldscore;
				$tokens{'newscore'} = $newscore;
				$tokens{'increment'} = $increment;
				$self->privmsg( $channel_name, &miniLanguage($smsg,%tokens) );
			}
			elsif( /language/ )
			{
				$tokens{'oldlanguage'} = $language;
				$language = $command_args[0];
				&debug( "Got language request for $language" );
				$config_file = "${language}_config.dat";
				$tokens{'newlanguage'} = $language;

				my (@channels) = split( / /, $bot_channel_list );
				my ($channel) = "";
				my ($smsg) = &miniLanguage( $language_changed_msg, %tokens );

				foreach $channel (@channels)
				{
					$self->privmsg( $channel, $smsg );
				}

				&loadConfigurationFile( $config_file );
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
				$self->privmsg( $nick, "say <channel> <text> - makes the bot say that text in channel" );
				$self->privmsg( $nick, "action <channel> <text> - the bot does \"/me <text>\"" );
				$self->privmsg( $nick, "restart - starts the bots perl script over" );
				$self->privmsg( $nick, "advertise - displays the bots version number in each channel" );
				$self->privmsg( $nick, "kick <channel> <user> [<message>] - the bot kicks user from channel with alternate kick message (you can set this to \"random\" and the bot will pick one for you!" );
				$self->privmsg( $nick, "kickban <channel> <user> [<message>] - the bot bans and then kicks this user from channel with alternate kick message (you can set this to \"random\" and the bot will pick one for you!" );
				$self->privmsg( $nick, "cycle <channel> - makes the bot leave and rejoin the channel" );
				$self->privmsg( $nick, "op <channel> <user> - the bot will set +o on user in channel" );
				$self->privmsg( $nick, "reload_configuration - the bot will reload it's config.dat file" );
				$self->privmsg( $nick, "score <channel> <user> <+/-> <amount> - the bot will change user's score by (+/-) amount" );
				$self->privmsg( $nick, "language <newlanguage> - the bot will change the language file to language_config.dat" );
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

	# load the configuration file
	&loadConfigurationFile( $config_file );

	# dump the variables we received from config file for debug
#	&debug( "Working Dir:\t$workingdir" );		&debug( "Server:\t\t$server:$port" );
#	&debug( "Password:\t$control_password" );	&debug( "Salt:\t\t$des_salt" );
#	&debug( "Nickname:\t$bot_nickname" );		&debug( "Nickserv Pass:\t$bot_nickserv_password" );
#	&debug( "Vhost Name:\t$bot_vhost_name" );	&debug( "Vhost Pass:\t$bot_vhost_pass" );
#	&debug( "Quotes File:\t$quotes_file" );		&debug( "Kickmsg File:\t$kickmsg_file" );
#	&debug( "Script Name:\t$script_name" );		&debug( "Pid Log:\t$pid_log" );
#	&debug( "Command Prefix:\t$command_prefix" );	&debug( "Greet msg:\t$greet_msg" );
#	&debug( "Valid Cmds:\t$valid_commands" );	&debug( "Chars/point:\t$chars_per_point" );
#	&debug( "Flood Det:\t$use_flood_detection" );	&debug( "Penalty:\t$flood_penalty" );
#	&debug( "Score Succ:\t$score_report_msg" );	&debug( "Score Err:\t$score_error_msg" );
#	&debug( "Score top10:\t$score_top10_format" );	&debug( "Add to db msg:\t$add_to_db_msg" );
#	&debug( "Bot will join:\t$bot_channel_list" );	&debug( "" );

	# if we are not running the same process, make sure the old one is dead 
	&debug ( "Attempting to open PID log and read last process" );
	
	open( INF, $pid_log ) or &die_nice("Could not open the PID log for reading");
	my ($killpid) = <INF>; # should be the very first line in the file, always
	close(INF);

	#Gets current process
	my ($pid) = $$;

	#Kill last process
	&debug( "Current pid: $pid\tOld pid: $killpid" );
	if ( $killpid != $pid ) {
		&debug( "Killing last process" );
		kill( 9, $killpid );
	}

	# Write out the new PID
	&debug( "Attempting to write new process ID to log" );
	open( OUTF, ">${pid_log}" ) or &die_nice("Could not open the PID log for writing");
	print OUTF $pid;
	close OUTF;


	# Set up our IRC connection
	&debug( "Connecting to $server:$port" );
	$irc_server_connection = $irc_module->newconn(
					Server   => $server,
					Port     => $port,
					Nick     => $bot_nickname,
					Ircname  => 'http://www.l8nite.net  &  http://www.slyfx.com',
					Username => $bot_nickname
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

	# Eliza bot inits
	# print "Initializing Eliza Chat Interface\n" if $debug == 1;
	# rand( time ^ ($$ + ($$ << 15)) );
	# my ($elizabot) = new Chatbot::Eliza "$botnick";

	exit;
}















#
# Mysql connection code for Pipsqueek
#


##################################################################################################
# Connect to the database
sub connectDB
{
	$dbh = DBI->connect('DBI:mysql:pipsqueek','<removed>','<removed>', { LongReadLen => 102400 }) or &debug("mysql.lib: Error connecting database");
}


##################################################################################################
# Generates an SQL query to the	database.  It will automatically connect the database if need be.
sub doQuery
{
	&connectDB() if $dbh eq "";

	my ($command) = $_[0];

	if($_[1] ne 1)
	{
	    $query = $dbh->prepare($command) || &debug("mysql_l8nitedb.lib: Error preparing statement");
	    $query->execute || &debug("mysql_l8nitedb.lib: Error executing command\n\t$command\n\t$DBI::errstr");
	}
	else
	{
	    $query2 = $dbh->prepare($command) || &debug("mysql_l8nitedb.lib: Error preparing statement");
	    $query2->execute || &debug("mysql_l8nitedb.lib: Error executing command\n\t$command\n\t$DBI::errstr");
	}
}



##################################################################################################
# Releases the query results
sub finishQuery{ $query->finish() unless $query eq "";$query="";$query2->finish() unless $query2 eq ""; $query2 = "";}


##################################################################################################
# Releases the database connection 
sub disconnectDB{ $dbh->disconnect unless $dbh eq ""; $dbh=""; }


##################################################################################################
# Finishes all query handles and closes the database
sub finishUp
{
	&finishQuery();
	&disconnectDB();
}

1;
