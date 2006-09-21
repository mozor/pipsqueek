#!/usr/bin/perl

#
#	PipSqueek [version 1.0.12]
#	© 2001 slyfx [slyfx@slyfx.com] & l8nite [l8nite@l8nite.net]
#	Shouts to trapper for giving us help/tips and ideas
#
#	07|10|2001
#	Complete rewrite done by l8nite
#
# 	TODO:
#	1 - finish seen, stats, and nick-change following, also implement multi-channel
#	2 - secure bot against flooding, ctcp attacks, and the like
#	3 - add remote control features for admins
#	4 - make the bot do something random when idle
#	5 - umm... do something else k? ;)

#Modules
use strict;
push(@INC, ".");
use Net::IRC;
#use Chatbot::Eliza;

my ($config_file) = "config.dat";
# this is where all the configuration will be provided from

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
	$stats_file,		# stats file for user points
	$seen_file,		# seen file for user last seen times
	$quotes_file,		# random quotes file for humor
	$kickmsg_file,		# random kick messages datafile
	$script_name,		# the bots actual script name
	$pid_log,		# so we can kill our old processes
	$swap_file,		# to keep track of nickname changes
	$command_prefix,	# type as first character for bot command
	$valid_commands,	# the valid commands for this bot
	$chars_per_point,	# how many chars a person says per point
	$score_report_msg,	# what the bot says when reporting scores
	$score_error_msg	# what the bot says on not finding score
);

# Bot-globals
my (%font_style) = (
	bold	=>	chr(0x02),
);

my ($version) = "PipSqueek version 1.0.12-dev by l8nite";
my ($accepted_characters) = ' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890~!@#$%^&*()_+`- =[]{};:<>,.?/|';
my ($irc_module) = new Net::IRC;
my ($irc_server_connection);


#################
# The main function is at the bottom of the script =)
#######

###########################################################################
# loads the configuration file passed into $_[0]
# expects the config file to be in the same directory as the bot and the
# perl script has to have defined the appropriate variables.
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
# What to do when the bot successfully connects.
sub on_connect
{
	my ($self, $event) = @_;

	print "Joining channels: $bot_channel_list\n" if $debug == 1;
	my ($botchanlist) = $bot_channel_list;
	$botchanlist =~ s/ /,/g;

	# Tell the server that this is a bot
	$self->sl("MODE $bot_nickname +B");

	# Message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $bot_nickserv_password");

	# Set ourselves up with the vhost
	if( $bot_vhost_name ne "" )
	{
		$self->sl("VHOST $bot_vhost_name $bot_vhost_pass");
	}

	# Join our channels
	$self->join( $botchanlist );
}


###########################################################################
# What happens when the bot gets disconnected (ping timeout, etc)
sub on_disconnect
{
	print "Bot was disconnected from network, reconnecting\n" if $debug == 1;
	my ($self, $event) = @_;
	$self->connect();
}


###########################################################################
# CTCP Version reply
sub on_version 
{
	my ($self, $event) = @_;
	my $nick = $event->nick;

	print "Received CTCP VERSION request from $nick\n" if $debug == 1;

	$self->ctcp_reply($nick, $version);
}


###########################################################################
# CTCP Ping reply
sub on_ping
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($arg) = ($event->args);

	print "Received CTCP PING request from $nick\n" if $debug == 1;

	$self->ctcp_reply($nick, "PONG! $arg");
    	#$self->ctcp_reply($nick, "PING $arg");
}


###########################################################################
# Handles some messages you get when you connect
sub on_init
{
	my ($self, $event) = @_;
	my (@args) = ($event->args);
	shift (@args);
	print "*** @args\n" if $debug == 1;
}


###########################################################################
# Someone has joined, what should we do ?
sub on_join
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;

	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);

	my ($channel_from) = ($event->to);

	print "$nick joined the channel, writing to swap file: ${channel_from}.${swap_file}\n" if $debug == 1;

	# tell our swap file there's a new user on the channel
	open( OUTF, ">>${channel_from}.${swap_file}" ) or &die_nice( "Error in on_join opening file ${channel_from}.${swap_file}\n" );
	print OUTF $nick;
	print OUTF "\n";
	close( OUTF );

	`sleep 1`;

	my ($greeting) = $greet_msg;
	$greeting =~ s/::name::/$nick/g;

	$self->privmsg($channel_from, $greeting) unless $greet_msg eq "" || $nick eq $bot_nickname;
}


###########################################################################
# Someone has left, update the nick swap file
sub on_part
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;

	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);

	my ($channel_name) = $event->to;

	print "$nick has left the channel, writing to swap file: ${channel_name}.${swap_file}\n" if $debug == 1;

	open( INF, "${channel_name}.${swap_file}" ) or &die_nice( "Error in on_part opening file ${channel_name}.${swap_file}\n" );
	my (@lines) = <INF>;
	chomp(@lines);
	close(INF);

	open( OUTF, ">${channel_name}.${swap_file}" ) or &die_nice( "Error in on_part opening file ${channel_name}.${swap_file} for writing\n" );
	my ($line) = "";
	foreach $line ( @lines )
	{
		unless( $line =~ m/$nick$/ )
		{
			print OUTF $line;
			print OUTF "\n";
		}
	}
	close(OUTF);
}


###########################################################################
# Someone has left the server, update every file we have with his name in it
sub on_quit
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;

	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);

	my (@channels) = split( / /, $bot_channel_list );

	# since quitting the server isn't channel-related we need to update ALL
	# the swap files for our bot.
	my ($curr_channel) = "";
	foreach $curr_channel (@channels)
	{
		open( INF, "${curr_channel}.${swap_file}" ) or &die_nice( "Error in on_quit opening file ${curr_channel}.${swap_file}\n" );
		my (@lines) = <INF>;
		chomp(@lines);
		close(INF);

		open( OUTF, ">${curr_channel}.${swap_file}" ) or &die_nice( "Error in on_quit opening file ${curr_channel}.${swap_file} for writing\n" );
		my ($line) = "";
		foreach $line ( @lines )
		{
			unless( $line =~ m/$nick$/ )
			{
				print OUTF $line;
				print OUTF "\n";
			}
		}
		close(OUTF);
	}
}


###########################################################################
# On nick change, update the swap files
sub on_nick
{
	my ($self, $event) = @_;
	my ($nick) = $event->nick;

	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);

	my ($new_nick) = ($event->args);
	my (@channels) = split( / /, $bot_channel_list );

	# since nickname changes aren't channel-related we need to update ALL
	# the swap files for our bot.
	my ($curr_channel) = "";
	foreach $curr_channel (@channels)
	{
		print "$nick changed nicknames to $new_nick, searching through ${curr_channel}.${swap_file} to update references\n" if $debug == 1;

		open( INF, "${curr_channel}.${swap_file}" ) or &die_nice( "Error in on_nick opening file ${curr_channel}.${swap_file}\n" );
		my (@lines) = <INF>;
		chomp(@lines);
		close(INF);

		open( OUTF, ">${curr_channel}.${swap_file}" ) or &die_nice( "Error in on_nick opening file ${curr_channel}.${swap_file} for writing\n" );
		my ($line) = "";
		foreach $line ( @lines )
		{
			if( $line =~ m/^$new_nick/ )
			{
				print OUTF $new_nick;
				print OUTF "\n";
			}
			elsif( $line =~ m/$nick$/ )
			{
				$line .= " $new_nick";
				print OUTF $line;
				print OUTF "\n";
			}
			else
			{
				print OUTF $line;
				print OUTF "\n";
			}
		}
		close(OUTF);
	}
}


###########################################################################
# What should we do when someone gets kicked ?
sub on_kick
{
	my ($self, $event) = @_;

	my ($person_kicked) = $event->to;
	my ($the_kicker, $my_nick) = ($event->nick, $self->nick);
	my ($channel_kicked_from) = ($event->args);

	my ($kick_message) = &randomLine( $kickmsg_file );

	print "$person_kicked was booted from $channel_kicked_from, updating swap file ${channel_kicked_from}.${swap_file}\n" if $debug == 1;

	if ( $person_kicked eq $my_nick ){
		$self->join($channel_kicked_from);
		`sleep 3`;
		$self->kick( $channel_kicked_from, $the_kicker, $kick_message );
	}
	else
	{
		# they technically "left" the room, so we remove from swap
		open( INF, "${channel_kicked_from}.${swap_file}" ) or &die_nice( "Error in on_kick opening file ${channel_kicked_from}.${swap_file}\n" );
		my (@lines) = <INF>;
		chomp(@lines);
		close(INF);

		open( OUTF, ">${channel_kicked_from}.${swap_file}" ) or &die_nice( "Error in on_kick opening file ${channel_kicked_from}.${swap_file} for writing\n" );
		my ($line) = "";
		foreach $line ( @lines )
		{
			unless( $line =~ m/$person_kicked$/ )
			{
				print OUTF $line;
				print OUTF "\n";
			}
		}
		close(OUTF);
	}
}


###########################################################################
# If we are banned
sub banned
{
	my ($self, $event) = @_;
	my ($mynick) = ($self->nick);
	my (@arg) = ($event->args);

	print "$mynick was banned from $arg[1], unbanning.\n";

	# let's make sure we are who we want to be first
	$self->sl("NICK $bot_nickname");

	# Message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $bot_nickserv_password");

	$self->privmsg("ChanServ", "UNBAN $arg[1]");
	$self->join( $arg[1] );
}


###########################################################################
# If someone is using our nickname
sub on_nick_taken
{
	my ($self, $event) = @_;
	$event->dump;
	my (@args) = ($event->args);

	print "Nickname $bot_nickname was taken, attempting to ghost\n" if $debug == 1;

	$self->sl("NICK b1shKill3r");
	`sleep 1`;
	$self->privmsg("NickServ", "GHOST $args[1] $bot_nickserv_password");
	`sleep 1`;
	$self->sl("NICK $bot_nickname");

	# Message nickname services to identify that we are who we say we are
	$self->privmsg("NickServ", "IDENTIFY $bot_nickserv_password");

	# Tell the server that this is a bot
	$self->sl("MODE $bot_nickname +B");

	# Set ourselves up with the vhost
	if( $bot_vhost_name ne "" )
	{
		$self->sl("VHOST $bot_vhost_name $bot_vhost_pass");
	}
}


###########################################################################
# What to do when we receive channel text.
sub on_public
{
	my ($self, $event) = @_;
	my ($nick) = ($event->nick);
	my ($channel_text) = ($event->args);

	# Clean up the channel text
	$channel_text =~ s/[^\Q$accepted_characters\E]//g;

	# Output the text from IRC... useful for monitoring..	
	print "<$nick> $channel_text\n" if $debug == 2;

	# Only process the first 50 chars
	if ( (length($channel_text) > 50) )
	{
    		$channel_text = substr($channel_text, 0, 50);
	}
    
	# Find out if this is a command
	if( substr( $channel_text, 0, 1 ) eq $command_prefix )
	{
		# The first character was a command prefix, now make sure it's not been disabled by our config file
		my (@temp) = split( / /, $channel_text );
		my ($len) = length $temp[0];
		my ($command) = substr( $temp[0], 1, $len - 1 );
		my ($command_args) = $temp[1];

		my ($vclist) = $valid_commands;

		#watchtower was here.
		# <Project1> yum, perl
		# <Project1> ick, 
		# * Project1 spits it out
		# <Project1> larry wall tastes like shit
		# <Wolfjourn> perl is like that hoe you see on the street corner.. only looks good when you're not getting it

		if(  $vclist =~ m/$command/gi  )
		{
			&process_command( $self, $event, $command, $command_args );
		}
		else
		{
			&process_plaintext( $self, $event );
		}
	}
	else
	{
		&process_plaintext( $self, $event );
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

		if ( $debug == 1 )
		{
			print "Names list received for $channel_name writing: ";
			my ($dstring) = "";
			foreach(@names)	{ $dstring .= "$_, "; }
			chop($dstring);	chop($dstring);
			$dstring .= " to ${channel_name}.${swap_file}\n";
			print $dstring;
		}

		# print out each name in the channel to our swap file, so we can keep track of nickname
		# changes and increment the appropriate score in the database
		open( OUTF, ">${channel_name}.${swap_file}" ) or &die_nice( "Error in on_names opening file ${channel_name}.${swap_file} for writing\n" );
		foreach( @names )
		{
			$_ =~ s/.// if ($_ =~ m/[\^\+\@\%]/);
			print OUTF $_;
			print OUTF "\n";
		}
		close(OUTF);
	}
}


###########################################################################
# Handles plaintext to the bot
sub process_plaintext()
{
	my ($self, $event) = @_;
	# scoring function goes here, also increments the timer for our
	# brand new idle song singing thing

	my ($nick) = ($event->nick);
	my ($channel_text) = ($event->args);
	my ($channel_name) = ($event->to);

	# Clean up the channel text
	$channel_text =~ s/[^\Q$accepted_characters\E]//g;

	# Only process the first 50 chars
	if ( (length($channel_text) > 50) )
	{
    		$channel_text = substr($channel_text, 0, 50);
	}


	# Let's find out who they really are in the swap file
	open( INF, "${channel_name}.${swap_file}" ) or &die_nice( "Error in process_plaintext opening file ${channel_name}.${swap_file} for writing\n" );
	my (@swaplines) = <INF>;
	chomp( @swaplines );
	close(INF);

	my ($flag) = 0;
	my ($liner) = "";
	foreach $liner ( @swaplines )
	{
		if( $liner =~ m/$nick$/ )
		{
			$flag = 1;
			my(@parts) = split( / /, $liner );
			$nick = $parts[0];
		}
		last if $flag == 1;
	}

	# now let's increment their score
	
	open( INF, "${channel_name}.${stats_file}" ) or &die_nice( "Error in process_plaintext opening file ${channel_name}.${stats_file}\n" );
	my (@lines) = <INF>;
	chomp(@lines);
	close(INF);

	my ($found_flag) = 0;
	my ($len) = length $channel_text;

	open( OUTF, ">${channel_name}.${stats_file}" ) or &die_nice( "Error in process_plaintext opening file ${channel_name}.${stats_file} for writing\n" );
	my ($line) = "";
	foreach $line (@lines)
	{
		if( $line =~ m/^$nick/ )
		{
			$found_flag = 1;

			my (@parts) = split( /:/, $line );

			$parts[2] += $len;
			while( $parts[2] > $chars_per_point )
			{
				$parts[1] += 1;
				$parts[2] -= $chars_per_point;
			}

			print OUTF "$parts[0]:$parts[1]:$parts[2]\n";
		}
		else
		{
			print OUTF $line;
			print OUTF "\n";
		}
	}

	# if the user wasn't in the database already we need to add him
	if( $found_flag == 0 )
	{
		print OUTF "$nick:0:$len\n";
	}

	close(OUTF);
}


###########################################################################
# Handles the valid commands for our bot
sub process_command()
{
	my ($self, $event, $command, $command_args) = @_;
	my ($nick) = ($event->nick);
	my ($channel_text) = ($event->args);
	my ($the_channel) = ($event->to);



	# Let's find out who is issuing the command
	# by checking in our handy dandy - swap file

	open( INF, "${the_channel}.${swap_file}" ) or &die_nice( "Error in process_command opening file ${the_channel}.${swap_file}\n" );
	my (@swaplines) = <INF>;
	chomp( @swaplines );
	close(INF);

	my ($flag) = 0;
	my ($liner) = "";
	foreach $liner ( @swaplines )
	{
		if( $liner =~ m/$nick$/ )
		{
			$flag = 1;
			my(@parts) = split( / /, $liner );
			$nick = $parts[0];
		}
		last if $flag == 1;
	}


	# process the commands

	foreach( lc($command) )
	{
		if( /quote/ )
		{
			my ($quote_message) = &randomLine( $quotes_file );
			$self->privmsg( $the_channel, $quote_message );
		}
		elsif( /score/ )
		{
			if( $command_args ne "" )
			{
				$nick = $command_args;
			}
			open( INF, "${the_channel}.${stats_file}" ) or &die_nice( "Error in process_command opening file ${the_channel}.${stats_file}\n" );
			my (@lines) = <INF>;
			chomp(@lines);
			close(INF);

			my ($smsg) = $score_report_msg;
			my ($emsg) = $score_error_msg;

			my ($line) = "";
			my ($found_flag) = 0;
			foreach $line (@lines)
			{
				if( $line =~ m/^$nick/ )
				{
					$found_flag = 1;
					my (@parts) = split( /:/, $line );
					$smsg =~ s/::name::/$nick/g;
					$smsg =~ s/::score::/$parts[1]/g;
					$smsg =~ s/::plural:://g if( $parts[1] == 1 );
					$smsg =~ s/::plural::/s/g;
				}
			}

			if( $found_flag == 0 )
			{
				$emsg =~ s/::name::/$nick/g;
				$self->privmsg( $the_channel, $emsg );
			}
			else
			{
				$self->privmsg( $the_channel, $smsg );
			}
		}
		elsif( /top10/ )
		{
			my (@high_scores);
			my (%scorers);
			my ($linecounter) = 0;

			open( INF, "${the_channel}.${stats_file}" ) or &die_nice( "Error in process_command opening file ${the_channel}.${stats_file}\n" );
			my (@lines) = <INF>;
			chomp(@lines);
			close(INF);

			my ($line);
			foreach $line ( @lines )
			{
				my (@parts) = split( /:/, $line );
				$high_scores[$linecounter] = $parts[1];
				$scorers{$parts[0]} = $parts[1];
				$linecounter++;
			}

			my (@high_scores) = sort by_number @high_scores;

			my ($final_line) = "Top 10: ";

			my ($newcounter) = 0;
			$linecounter = 0;
			while( $linecounter < 10 )
			{
				my ($liner);
				foreach $liner ( keys(%scorers) )
				{
					if( $high_scores[$linecounter] == $scorers{$liner} )
					{
						$final_line .= "$liner ($scorers{$liner}), ";
						$scorers{$liner} = -1;
						last;
					}
				}
				$linecounter++;
			}

			chop $final_line;
			chop $final_line;

			$self->privmsg( $the_channel, $final_line );
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
# Numeric sort comparison function
sub by_number
{
	if ($a > $b) {
		return -1;
	} elsif ($1 == $b) {
		return 0;
	} elsif ($a < $b) {
		return 1;
	}
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
	&die_nice( "You must supply the bot's nickserv password\nas the first argument to this script" ) if $ARGV[0] eq "";
	$bot_nickserv_password = $ARGV[0];

	# load the configuration file
	&loadConfigurationFile( $config_file );

	# make sure we have a vhost username and password
	if( $bot_vhost_name ne "" )
	{
		&die_nice( "You must supply the bot's vhost password\n as the second argument to this script\n if you wish to use vhost username: $bot_vhost_name" ) if $ARGV[1] eq "";
		$bot_vhost_pass = $ARGV[1];
	}

	# dump the variables we received from config file for debug
	if( $debug == 1 )
	{
		print "Server:\t\t$server:$port\n";
		print "Working Dir:\t$workingdir\n";
		print "Password:\t$control_password\n";
		print "Salt:\t\t$des_salt\n";
		print "Nickname:\t$bot_nickname\n";
		print "Nickserv Pass:\t$bot_nickserv_password\n";
		print "Vhost Name:\t$bot_vhost_name\n";
		print "Vhost Pass:\t$bot_vhost_pass\n";
		print "Stats File:\t$stats_file\n";
		print "Seen File:\t$seen_file\n";
		print "Quotes File:\t$quotes_file\n";
		print "Script Name:\t$script_name\n";
		print "Pid Log:\t$pid_log\n";
		print "Swap File:\t$swap_file\n";
		print "Command Prefix:\t$command_prefix\n";
		print "Bot will join:\t$bot_channel_list\n";
		print "\n";
	}

	# if we are not running the same process, make sure the old one is dead 
	print "Attempting to open PID log and read last process\n" if $debug == 1;
	
	open( INF, $pid_log ) or &die_nice("Could not open the PID log for reading");
	my ($killpid) = <INF>; # should be the very first line in the file, always
	close(INF);

	#Gets current process
	my ($pid) = $$;

	#Kill last process
	print "Current pid: $pid\tOld pid: $killpid\n" if $debug == 1;
	if ( $killpid != $pid ) {
		print "Killing last process\n" if $debug == 1;	
		kill( 9, $killpid );
	}

	# Write out the new PID
	print "Attempting to write new process ID to log\n" if $debug == 1;
	open( OUTF, ">${pid_log}" ) or &die_nice("Could not open the PID log for writing");
	print OUTF $pid;
	close OUTF;


	# Set up our IRC connection
	print "Connecting to $server:$port\n" if $debug == 1;
	$irc_server_connection = $irc_module->newconn(
					Server   => $server,
					Port     => $port,
					Nick     => $bot_nickname,
					Ircname  => 'http://www.l8nite.net  &  http://www.slyfx.com',
					Username => 'PipSqueek'
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
