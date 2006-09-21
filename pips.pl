#!/usr/bin/perl

#PipSqueek [version 0.3.0]
#Copyright 2001 slyfx [slyfx@slyfx.com]  l8nite [l8nite@l8nite.net]
#Shouts to trapper for giving us help/tips and ideas

	#	TODO List:
	#	Needs to be refined and the processing speeded up
	#	Add self defence code to stop deoping/banning of bot etc [90% DONE]
	#	Tidy up nick bans maybe? Like DHC does
	#	Add remote control code, so I can control the bot via password/queries [DONE]
	#	Add response code for a site bot to query the userlist [DONE]
	#	Add code to re-compile/spawn every hour [Not script based -> use Crontab]
	#	Add code to log users joining/leaving (Like DHC) [90% DONE]
	#	Ident matching needs improving
	#	Add code to do stats (Like subordinate) [80% DONE] ->
	#	Tidy up !rank command to list multiple users on same rank
	#	If too many users are there, send a message saying so
	#	Add code to stop users repeating queries within a certain time limit
	#	Change all code that prints or warns to append an error file


#Modules
use strict;
push(@INC, ".");
use Net::IRC;
use Chatbot::Eliza;

# Global Variables

my ($debug) = 1;
# set to 0 to have the bot not report it's status to stdout

my ($workingdir) = "/home/l8nite/";
# edit this to point to the directory where all the data files and pips.pl is located

my ($config_file) = "$workingdir

MAIN: {
	# program entry point
}



#Constants
my ($server) = "irc.x0z.org";
my ($workingdir) = "/home/l8nite/";
my ($authpass) = "<removed>";
my ($botpass) = "<removed>";
my ($botnick) = "PipSqueek";
my ($botchannel) = "#watchtower";
my ($statsfile) = "$workingdir/statsdb.txt";
my ($seenfile) = "$workingdir/seendb.txt";
my ($quotesfile) = "$workingdir/quotes.txt";
my ($sitefile) = "$workingdir/sitedb.txt";
my ($scriptname) = "$workingdir/pips.cgi";
my ($pidlog) = "$workingdir/pidlog.txt";
my ($bold) = chr(0x02);
my ($version) = "VERSION PipSqueek version: 0.10alpha by: slyfx";
my ($accept)= ' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890~!@#$%^&*()_+`- =[]{};:<>,.?/|';
my ($flagger) = 0;



#Flood constants for each type of msg event, in the form of lines per second
#l == lines, s == seconds, c == count
my (%floods) = ( PRIVMSGl	=>	3,
				 PRIVMSGs	=>	2,
				 PRIVMSGc	=>	0,
				 CTCPl		=>  3,
				 CTCPs		=>  2,
				 CTCPc		=>  0,
			   );

#Variables
my (@linetimes) = ();
my (@nameslist) = ();
my ($lastrequest) = "10";
my ($init) = 0;
my ($elizamode) = 0;

print "\n\nInitializing Eliza Chat Interface\n" if $debug == 1;
#Eliza bot inits
srand( time ^ ($$ + ($$ << 15)) );
my ($elizabot) = new Chatbot::Eliza "$botnick";

print "\nAttempting to open PID log and read last process\n" if $debug == 1;
#Opens PID log to read the last process
open LOGPID, "$pidlog" or die print "ERROR: Attempting to open pidlog";
my ($killpid) = <LOGPID>;
close LOGPID;

#Gets current process
my ($pid) = $$;


#Kill last process
if ($killpid != $pid) {
    print "\nKilling last process\n" if $debug == 1;
	kill 9, $killpid;
}

print "\nWriting to PID log\n" if $debug == 1;
#Opens PID log for writing
open LOGPID, ">$pidlog" or die print "ERROR: Attempting to open pidlog";
print LOGPID $pid;
close LOGPID;

#The die routine
sub killme {
	print $_[0];
	print "[DONE]\n";
	exit;	
}

#Initialise the IRC subs and variables
my $irc = new Net::IRC;

#Connection setup
my $conn = $irc->newconn(Server   => ($server),
						 Port     => 6667,
						 Nick     => $botnick,
						 Ircname  => 'www.slyfx.com and http://aspect.l8nite.net r0x',
						 Username => 'BOT') or killme "Failed to make connection to irc server.\n";
			 
#Floodcheck routine this insures the bot does not process massive floods
#Should help prevent ctcp attacks
#This is bad programming imho - but for now it will suffice
sub floodchk {
	my ($type) = $_[0];
	#Is the limit buffer full?
	if ($floods{$type . 'c'} == ($floods{$type . 'l'} - 1)) {
		my ($loop) = 0;
		#Check status for private messages
		if ($type eq "PRIVMSG") {
			for ($loop = 0; $loop < ($floods{$type . 'c'} - 1); $loop++) {
				$linetimes[0][$loop] = $linetimes[0][$loop + 1];
			}
			$linetimes[0][$floods{$type . 'c'}] = time();
			#Looks at the time passed for the $floods{$type . 'c'} lines sent
			return (($linetimes[0][$floods{$type . 'c'}] - $linetimes[0][0]) <= $floods{$type . 's'});
		#Check status for ctcp events
		} elsif ($type eq "CTCP") {
			for ($loop = 0; $loop < ($floods{$type . 'c'} - 1); $loop++) {
				$linetimes[1][$loop] = $linetimes[1][$loop + 1];
			}
			$linetimes[1][$floods{$type . 'c'}] = time();
			#Looks at the time passed for the $floods{$type . 'c'} lines sent
			return (($linetimes[1][$floods{$type . 'c'}] - $linetimes[1][0]) <= $floods{$type . 's'});
		}
	#Add another line to the limit buffer
	} else {
		if ($type eq "PRIVMSG") {
			$linetimes[0][$floods{$type . 'c'}] = time();
		} elsif ($type eq "CTCP") {
			$linetimes[1][$floods{$type . 'c'}] = time();
		}
		$floods{$type . 'c'}++;
		return 0;
	}
}

#User command routine
sub usercmd {
	if (length($_[0]) > 4) {
		my (@tempar) = split(/ /, $_[0]);
		return ((lc($tempar[0]) eq "!rank") || (lc($tempar[0]) eq "!score") || (lc($tempar[0]) eq "!seen") || (lc($tempar[0]) eq "!top10") || (lc($tempar[0]) eq "!quote") ||(lc($tempar[0]) eq "pipsqueek:") || (lc($tempar[0]) eq "pips:"));
		#(lc($tempar[0]) eq "!slyfx") || || (lc($tempar[0]) eq "!aspect")
	} else {
		return 0;
	}
}

#Stat calculation routine
sub calcstat {
	my ($mainstat, $substat) = @_;
	while ($substat > 99) {
		$mainstat += 1;
		$substat -= 100;
	}
	return ($mainstat, $substat);
}

#Numeric comparison function
sub by_number {
	if ($a > $b) {
		return -1;
	} elsif ($1 == $b) {
		return 0;
	} elsif ($a < $b) {
		return 1;
	}	
}

#Sorts the database by the scores
#This is called everytime a !score or !rank request is received
#This is bad programming imho - but for now it will suffice
sub resort {
	open(INF, "$statsfile");
	my (@lines) = <INF>;
	close(INF);
	#Hash containing name => score
	my (%namescr) = ();
	#Hash containing name => statsfile line
	my (%namelne) = ();
	my (@items) = "";
	foreach (@lines) {
		@items = split(/:/);
		$namescr{(($items[1] * 100) + $items[2])} = $items[0];
		$namelne{$items[0]} = $_;
	}
	#Sorts score
	@items = sort by_number keys(%namescr);
	open(OUTF, ">$statsfile");
	flock(OUTF, 2);
	#Prints the statsfile lines in their sorted order
	foreach (@items) {
		print OUTF $namelne{$namescr{$_}};
	}
	close(OUTF);
}

#Returns seconds to wait until next request should be made (if any)
sub cmdrequest {
	my ($currenttime) = time();
	my ($newrequest) = $currenttime;
	$currenttime -= $lastrequest;
	#Looks at time difference between present and last request
	if ($currenttime < 3) {
		$currenttime = 3 - $currenttime;
		$currenttime = 3 if (($currenttime > 3) || ($currenttime < 0));
		#Returns seconds left for user to wait
		return $currenttime;
	} else {
		#No need to wait
		$lastrequest = $newrequest;
		return 0;
	}
}

#Checks to see if a user is currently on the channel
sub onchannel {
	my ($nick) = $_[0];
	my ($seen) = 0;
	foreach (@nameslist) {
		my (@items) = split(/ /);
		foreach (@items) {
			s/.// if (m/[\^\+\@\%]/);
			$seen = 1 if (lc eq $nick);
		}
	}
	return $seen;
}

sub timediff {
	my ($lapse) = (time - $_[0]);
	my ($line) = "";
	my ($days) = 0;
	my ($hours) = 0;
	my ($minutes) = 0;
	while ($lapse >= 86400) {
		$lapse -= 86400;
		$days += 1;
	}
	while ($lapse >= 3600) {
		$lapse -= 3600;
		$hours += 1;
	}
	while ($lapse >= 60) {
		$lapse -= 60;
		$minutes += 1;
	}
	$line = "$days days " if ($days > 0);
	$line .= "$hours hrs " if ($hours > 0);
	$line .= "$minutes mins " if ($minutes > 0);
	$line .= "$lapse secs " if ($lapse > 0);
	return "$line";
}

#Join my channel
sub on_connect {
	print "CONNECTING TO NEW CHANNEL\n";
	my $self = shift;
	$self->sl("MODE $botnick +B");
	$self->privmsg("NickServ", "IDENTIFY $botpass");
	$self->join($botchannel);
}

#Kill old nick
sub on_nick_taken {
	my $self = shift;
	$self->privmsg("NickServ", "GHOST $botnick $botpass");
	$self->sl("NICK $botnick");
	$self->privmsg("NickServ", "IDENTIFY $botpass");
}

#Version reply
sub on_version  {
	if (not floodchk("CTCP")) {
	    my ($self, $event) = @_;
	    my $nick = $event->nick;
	    $self->ctcp_reply($nick, $version);
    }
}

#Ping reply
sub on_ping {
	if (not floodchk("CTCP")) {
	    my ($self, $event) = @_;
	    my ($nick) = $event->nick;
	    my ($arg) = ($event->args);
    	$self->ctcp_reply($nick, "PING $arg");
	}
}

# Handles some messages you get when you connect
#Temp sub routine for testing
sub on_init {
    my ($self, $event) = @_;
    my (@args) = ($event->args);
    shift (@args);

    print "*** @args\n\n";
}

# What to do when we receive a private PRIVMSG.
sub on_msg {
    #Checks to make sure bot isnt being flooded
    if (not floodchk("PRIVMSG")) {
    	my ($self, $event) = @_;
    	my ($nick) = $event->nick;
    	my ($liner) = $event->args;
    	my (@argspassed) = split(/ /, $liner);

       print "PRIV: <$nick> $liner\n";

    	#Checks password
    	if ($argspassed[0]) {
	    	if ($argspassed[0] eq $authpass) {
	    		if ($argspassed[1]) {
		    		#List names in channel
		    		if (lc($argspassed[1]) eq "names") {
		    			$self->privmsg($nick, "Here are the list of names for $botchannel :");
		    			foreach (@nameslist) {
		    				$self->privmsg($nick, $_);
		    			}
		    			$self->privmsg($nick, "!END!");
		    		#Speak in channel
		    		} elsif (lc($argspassed[1]) eq "say") {
		    			$liner = substr($liner, length($authpass) + 5, length($liner) - (length($authpass) + 5));
		    			$self->privmsg($botchannel, $liner);
		    		#Shut the bot down
		    		} elsif (lc($argspassed[1]) eq "shutdown") {
		    			$self->quit("Shutting down...");
		    			exit;
		    		} elsif (lc($argspassed[1]) eq "eliza") {
		    			$elizamode = not $elizamode;
		    			if ($elizamode) {
		    				$self->privmsg($botchannel, "Eliza mode is now " . $bold . "on" . $bold);
		    			} else {
		    				$self->privmsg($botchannel, "Eliza mode is now " . $bold . "off" . $bold);
		    			}
				}
				# identify and join
				elsif( lc($argspassed[1]) eq "idjoin" )
				{
					$self->sl("MODE $botnick +B");
					$self->privmsg("NickServ", "IDENTIFY $botpass");
					$self->join($botchannel);
				}
		    		#Kick user
		    		elsif (lc($argspassed[1]) eq "kick") {
		    			$liner = substr($liner, length($authpass) + length($argspassed[2]) + 7, length($liner) - (length($authpass) + length($argspassed[2]) + 7));
		    			$self->kick($botchannel, $argspassed[2], $liner);
		    		#Kickban user
		    		} elsif (lc($argspassed[1]) eq "kickban") {
		    			$self->sl("MODE $botchannel +b $argspassed[2]!*@*");
		    			$liner = substr($liner, length($authpass) + length($argspassed[2]) + 10, length($liner) - (length($authpass) + length($argspassed[2]) + 10));
		    			$self->kick($botchannel, $argspassed[2], $liner);
		    		#Cycle the bot in the channel (leave and join)
		    		} elsif (lc($argspassed[1]) eq "cycle") {
		    			$self->sl("PART $botchannel Cycling...");
		    			$self->sl("JOIN $botchannel");
		    		#Action in the channel
			    	} elsif (lc($argspassed[1]) eq "action") {
		    			$liner = substr($liner, length($authpass) + 8, length($liner) - (length($authpass) + 8));
		    			$self->ctcp("ACTION", $botchannel, $liner);
		    		#Restarts/compiles the bot
		    		} elsif (lc($argspassed[1]) eq "restart") {
		    			$self->quit("Restarting");
		    			exec("perl $scriptname");
       		    		} elsif(lc($argspassed[1]) eq "advertise"){
					$self->privmsg($botchannel, "     \"More than just a friendly bot\"\n");
					$self->privmsg($botchannel, "    _.-|   |          |\__/,|   (`\\\n");
					$self->privmsg($botchannel, "   {   |   |          |o o  |__ _) )\n");
					$self->privmsg($botchannel, "    \"-.|___|        __( T   )  `  /\n");
					$self->privmsg($botchannel, "     .--'-`-.     _(._ `^--' /_<  \\\n");
					$self->privmsg($botchannel, "   .+|______|__.-||__)`-'(((/  (((/\n");
		    		} elsif (lc($argspassed[1]) eq "score") {
						#Opens and reads stats database file
						open(INF, "$statsfile");
						my (@userlines) = <INF>;
						close(INF);
						#Looks for nick and updates file
						my (@userstats) = "";
						my($found) = 0;
						open(OUTF, ">$statsfile");
						flock(OUTF, 2);
						foreach (@userlines){
							@userstats = split(/:/);
							#If nick is already in the db
							if ($userstats[0] eq lc($argspassed[2]))
							{
								$self->privmsg($nick, "Found username $userstats[0]");
								$found = 1;
								$userstats[1] = $userstats[1] + $argspassed[4] if $argspassed[3] =~ m/\+/i;
								$userstats[1] = $userstats[1] - $argspassed[4] if $argspassed[3] =~ m/\-/i;
								$argspassed[2] = lc($argspassed[2]);
								print OUTF "$argspassed[2]:$userstats[1]:$userstats[2]:$userstats[3]";
								$self->privmsg($nick, "$argspassed[2]'s new score is now: $userstats[1]");
								$self->privmsg($botchannel, "$nick changed $argspassed[2]'s score: $argspassed[3]$argspassed[4]");
							} else {
								print OUTF $_;
							}
						}
						close(OUTF);
						$self->privmsg($nick, "Sorry, the user $argspassed[2] was not found\!") if (not $found);
					#Displays help for commands
		    		} elsif (lc($argspassed[1]) eq "help") {		 
		    			$self->privmsg($nick, "Command help:");
		    			$self->privmsg($nick, "<pass> action <text>    Makes the bot perform an action in the channel");
		    			$self->privmsg($nick, "<pass> cycle    This cycles/hops the bot in the channel");
		    			$self->privmsg($nick, "<pass> help    Your reading it now");
		    			$self->privmsg($nick, "<pass> kick <user> [<reason>]    This kicks a user from the channel");
		    			$self->privmsg($nick, "<pass> kickban <user> [<reason>]    This bans and kicks a user from the channel");
		    			$self->privmsg($nick, "<pass> names    This lists the users in the channel (for bot 2 bot links)");
		    			$self->privmsg($nick, "<pass> restart    This restarts/compiles the bot, VERY useful for updating etc.");
		    			$self->privmsg($nick, "<pass> say <text>    Makes the bot say <text> in the channel");
		    			$self->privmsg($nick, "<pass> score <user> [+/-] <amount>  adds/subtracts score to user");
		    			$self->privmsg($nick, "<pass> shutdown    Shuts the bot down (Do not use unless you have a VERY good reason)");
		    		}		    		
		    	}
		    } elsif ($elizamode) {
		    	my ($botsays) = $elizabot->transform( $liner );
				$self->privmsg($nick, "$botsays");
	    	}
	    }
	}
}

#Prints the names of people in a channel when we enter.
#This is so a cgi bot can log in a get the names of
#ppl in the channel without having to join
sub on_names {
    my ($self, $event) = @_;
    my (@list, $channel) = ($event->args);

    # splice() only works on real arrays. Sigh.
    ($channel, @list) = splice @list, 2;
	
	if (not $init) {
		$init = 1;
		#Adds the names to our global array
		@nameslist = ();
		foreach (@list) {
			my (@items) = split(/ /);
			foreach (@items) {
				if (m/[\^\+\@\%]/) {
					s/.//;
				}
				push(@nameslist, $_);
			}
		}
	}
}

# What to do when we receive channel text.
sub on_public {
    my ($self, $event) = @_;
    my ($nick) = ($event->nick);
    my ($arg) = ($event->args);

    # Output the text from IRC... useful for monitoring..
    print "<$nick> $arg\n";
    
    #Clean up the $arg
    $arg =~ s/[^\Q$accept\E]//g;
    #Only process the first 50 chars
    if ((length($arg) > 50) && ($elizamode)) {
    	$arg = substr($arg, 0, 50);
    }
    
    #Checks to see if a user has requested something
    if (usercmd($arg))	{
    	#Sees how long ago the last request was
    	my ($seconds) = &cmdrequest();
    	if (not $seconds) {
	    	my (@cmds) = split(/ /, $arg);
	    	#Run the !score code (needs to be made into a sub routine)
	    	if (lc($cmds[0]) eq "!score") {
			print "suck";
	    		&resort;
	    		#No args passed
	    		if (not $cmds[1]) {
	    			$self->privmsg($botchannel, "$nick: Use !score <nickname>");
	    		} else {
		    		open(INF, $statsfile);
		    		my (@list) = <INF>;
		    		close(INF);
		    		my ($counter) = 0;
		    		my ($seen) = 0;
		    		my ($prev) = -1;
		    		#Loop through the statsfile, looking for the user
		    		foreach (@list) {
		    			my (@items) = split(/:/);
		    			if ($items[1] != $prev) {
		    				$counter += 1;
		    			}
		    			if ($items[0] eq lc($cmds[1])) {
		    				$seen = 1;
		    				#User found, so display the score
		    				$self->privmsg($botchannel, "$cmds[1]'s score is $items[1], ranked $counter");
		    			}
		    			$prev = $items[1];
		    		}
		    		#If user not found
		    		if (not $seen) {
		    			if (lc($cmds[1]) eq "pipsqueek") {
		    				$self->privmsg($botchannel, "$cmds[1] is too $bold 133t $bold to be rated");
		    			} else {
		    				$self->privmsg($botchannel, "$cmds[1] isn't rated");
		    			}
		    		}
		    	}
		    #Runs eliza code
			} elsif (((lc($cmds[0]) eq "pips:") || (lc($cmds[0]) eq "pipsqueek:")) && ($elizamode)) {
				$arg = substr($arg, length($cmds[0]) + 1, length($arg) - (length($cmds[0]) + 1));
				my ($botsays) = $elizabot->transform( $arg );
				$self->privmsg($botchannel, "$nick: $botsays");
		    #Run the !seen code (needs to be made into a sub routine)
	    	} elsif (lc($cmds[0]) eq "!seen") {
	    		if (not $cmds[1]) {
	    			$self->privmsg($botchannel, "$nick: Use !seen <nickname>");
	    		} else {
	    			if (onchannel(lc($cmds[1]))) {
	    				$self->privmsg($botchannel, "$cmds[1] is currently on $botchannel");
	    			} else {
	    				$cmds[1] = lc($cmds[1]);
		    			open(INF, $seenfile);
		    			my (@lines) = <INF>;
		    			close(INF);
		    			my ($seenn) = 0;
		    			my ($seeni) = 0;
		    			my ($line) = "";
		    			#Loops through the seenfile looking for the user
		    			foreach (@lines) {
		    				if (not $seenn) {
			    				my (@items) = split(/!/);
			    				my (@ident) = split(/@/, $items[1]);
			    				#If nick found
			    				if (lc($items[0]) eq $cmds[1]) {
			    					$seenn = 1;
			    					my ($lag) = timediff($items[2]);
			    					$line = $bold . $items[0] . $bold . "!$ident[0]\@$ident[1] was last seen $lag" . "ago on $botchannel"; 
			    				} else {
			    					#Gets rid of that pesky ~
			    					$ident[0] =~ s/.// if ($ident[0] =~ m/[~]/);
									#If ident found
									if ((lc($ident[0]) eq $cmds[1]) && ($seenn == 0)) {
				    					$seeni = 1;
				    					my ($lag) = timediff($items[2]);
				    					$line = "$items[0]!" . $bold . $ident[0] . $bold . "\@$ident[1] was last seen $lag" . "ago on $botchannel"; 
				    				}
			    				}
		    				}
		    			}
		    			#If nothing found
		    			if ((not $seenn) && (not $seeni)) {
		    				$self->privmsg($botchannel, "Last seen: no match");
		    			} else {
		    				$self->privmsg($botchannel, $line);
		    			}
		    		}
				}
	    	} elsif (lc($cmds[0]) eq "!top10") {
	    	    open(INF, "$statsfile");
                my (@userlines) = <INF>;
              	close(INF);
              	my($counter) = 0;
              	
              	my($toprint) = "Top 10: ";
              	
              	while($counter < 10) {
          			my(@spl) = split(/:/,$userlines[$counter]);
          			if($counter < 9){
          				$toprint = $toprint . $spl[0] . " ($spl[1]), ";
          			} else {
          				$toprint = $toprint . $spl[0] . " ($spl[1]).";
          			}
          			$counter++;
              	}    	
			$self->privmsg($botchannel, $toprint);
	    	} elsif (lc($cmds[0]) eq "!quote") {
	    	    open(INF, "$quotesfile");

				my($line);
				srand;
				rand($.) < 1 && ($line = $_) while <INF>;
			
                close(INF);

				$self->privmsg($botchannel, $line);
		    } elsif (lc($cmds[0]) eq "!slyfx") {
		    	open(INF, "$sitefile");
				my(@lines) = <INF>;
	            close(INF);
				my($line);
				my ($seen) = 0;
				foreach(@lines)	{
					my(@stuff) = split(/:/,$_);
					if($stuff[0] eq lc($cmds[1]) && $stuff[1] eq "slyfx") {
						my($name) = $cmds[1];
						chomp($stuff[3]);
						$seen = 1;
						my($toput) = "$name is currently \"$stuff[3] " . $name . "\" on slyfx <www.slyfx.com>";
						$self->privmsg($botchannel, $toput);
					}
				}
				
				if($seen == 0)
				{
					my($toput) = "$cmds[1] is not currently playing Slyfx";
					$self->privmsg($botchannel, $toput);
				}
	    	} elsif (lc($cmds[0]) eq "!aspect") {
	    	    open(INF, "$sitefile");
				my(@lines) = <INF>;
				close(INF);
				my($line);
				my ($seen) = 0;
				foreach(@lines)	{
					my(@stuff) = split(/:/);
					if($stuff[0] eq lc($cmds[1]) && $stuff[1] eq "aspect") {
						my($name) = $cmds[1];
						chomp($stuff[3]);
						$seen = 1;
						my($toput) = "$name is currently \"$stuff[3] " . $name . "\" on Aspect <www.l8nite.net>";
						$self->privmsg($botchannel, $toput);
					}
				}
				
				if($seen == 0)
				{
					my($toput) = "$cmds[1] is not currently playing Aspect";
					$self->privmsg($botchannel, $toput);
				}
	    	#Run the !rank code (needs to be made into a sub routine)
	    	} elsif (lc($cmds[0]) eq "!rank") {
				&resort;		    	
	    		#If arg is a number
	    		if (($cmds[1] =~ /(\d+)/) && (not($cmds[1] =~ /[a-zA-Z|`\[\]\{\}\(\)_\-]/))) {
	    			open(INF, "$statsfile");
	    			my (@lines) = <INF>;
	    			close(INF);
	    			my ($counter) = 0;
		    		my ($prev) = -1;
		    		my (@user) = "", "";
		    		my ($seen) = 0;
		    		#Loops through the statsfile looking for the rank
	    			foreach (@lines) {
	    				my (@items) = split(/:/);
	    				$counter += 1 if ($items[1] != $prev);
		    			if (($counter == $cmds[1]) && (not $seen)) {
		    				#Rank found, store the user and score
		    				$seen = 1;
		    				$user[0] = $items[0];
		    				$user[1] = $items[1];
		    			}
		    			$prev = $items[1];
	    			}
	    			#Display result
	    			if (not(length($user[0]) < 1)) {
	    				$self->privmsg($botchannel, "$user[0]'s rank is $cmds[1] with a score of $user[1]");
	    			} else {
	    				$self->privmsg($botchannel, "No users found with a rating of $cmds[1]");
	    			}
	    		#Not number, so rank of user must have been requested
	    		} else {
	    			open(INF, "$statsfile");
	    			my (@lines) = <INF>;
	    			close(INF);
	    			my ($counter) = 0;
		    		my ($prev) = -1;
		    		my ($seen) = 0;
		    		#Loops through statsfile looking for user
	    			foreach (@lines) {
	    				my (@items) = split(/:/);
	    				$counter += 1 if ($items[1] != $prev);
		    			if ($items[0] eq lc($cmds[1])) {
		    				$seen = 1;
		    				#User found, display rank
		    				$self->privmsg($botchannel, "$cmds[1]'s rank is $counter with a score of $items[1]");
		    			}
		    			$prev = $items[1];
	    			}
	    			#User not found
	    			if (not $seen) {
	    				if (lc($cmds[1]) eq "pipsqueek") {
	    					$self->privmsg($botchannel, "$cmds[1] is too $bold 133t $bold to be ranked");
	    				} else {
	    					$self->privmsg($botchannel, "$cmds[1] is not currently ranked");
	    				}
	    			}
	    		}
	    	}
	    #Request made too soon after a previous one
	    } else {
	    	$self->notice($nick, "Please try again in $seconds seconds...");
	    }
	}
	#Normal talk; Up the stats (needs to be made into a sub routine)
	else {
    	#Opens and reads stats database file
    	open(INF, "$statsfile");
    	my (@userlines) = <INF>;
    	close(INF);
    	#Looks for nick and updates file
    	my (@userstats) = "";
    	my ($addnew) = 1;
    	open(OUTF, ">$statsfile");
    	flock(OUTF, 2);
    	foreach (@userlines) {
    		@userstats = split(/:/);
    		#If nick is already in the db
    		if ($userstats[0] eq lc($nick)) {
    			$addnew = 0;
    			($userstats[1], $userstats[2]) = calcstat($userstats[1], $userstats[2] + length($arg));
    			$nick = lc($nick);
    			print OUTF "$nick:$userstats[1]:$userstats[2]:$userstats[3]";
    		} else {
    			print OUTF $_;
    		}
    	}
    	#Add new nick to db
    	if ($addnew) {
    		my ($temp1, $temp2) = calcstat(0, length($arg));
    		$nick = lc($nick);
    		print OUTF "$nick:$temp1:$temp2:none\n";
    	}
    	close(OUTF);
    }
}

#Nick event, update seen db
sub seen {
	my ($nick) = $_[0];
    my ($ident) = $_[1];
    my ($host) = $_[2];
	my $newtime = time();
    open(INF, $seenfile);
    my (@lines) = <INF>;
    close(INF);
    my ($seen) = 0;
    #Open the file to rewrite
    open(OUTF, ">$seenfile");
    flock(OUTF, 2);
	#Loop through the file and look for the user
	foreach (@lines) {
		my (@items) = split(/!/);
		if ($nick eq $items[0]) {
			$seen = 1;
			print OUTF "$nick!$ident\@$host!$newtime\n";
		} else {
			print OUTF $_;
		}
	}
	if (not $seen) {
		print OUTF "$nick!$ident\@$host!$newtime\n";
	}
	close(OUTF);	
}

# Reconnect to the server when we die.
sub on_disconnect {
	my ($self, $event) = @_;
	$self->connect();
}

#On nick change, updates the nick list
sub on_nick {
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($arg) = ($event->args);
	my ($counter) = 0;
	$nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);
	foreach (@nameslist) {
		$nameslist[$counter] = $arg if ($_ eq $nick);
		$counter++;
	}
	my ($ident) = $event->user;
    my ($host) = $event->host;
    &seen($nick, $ident, $host);
}

#Someone has left, update the nick list
sub on_part {
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($ident) = $event->user;
    my ($host) = $event->host;
    my ($counter) = 0;
    my ($cought) = 0;
    $nick =~ s/.// if ($nick =~ m/[\^\+\@\%]/);
    foreach (@nameslist) {
    	$cought = $counter if ($_ eq $nick);
    	$counter++;
    }
    $nameslist[$cought] = $nameslist[-1];
    pop(@nameslist);
    &seen($nick, $ident, $host);
}

#Someone has joined, update the nick list
sub on_join {
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($ident) = $event->user;
    my ($host) = $event->host;
    push(@nameslist, $nick);
    &seen($nick, $ident, $host);
}

#Rejoin on kick
sub on_kick {
    my ($self, $event) = @_;
    my @to = $event->to;
    my ($nick, $mynick) = ($event->nick, $self->nick);
    my ($arg) = ($event->args);
	if ($to[0] eq $mynick) {
		$self->join($arg);
	}
}

#Get rid of our ban
sub banned {
	my ($self, $event) = @_;
    my ($mynick) = ($self->nick);
    my (@arg) = ($event->args);

	if (lc($arg[1]) eq $botchannel) {
		$self->privmsg("ChanServ", "unban $botchannel $botnick");
		$self->join($botchannel);
	}
}

#Add event handlers
$conn->add_global_handler(376, \&on_connect);
$conn->add_global_handler(433, \&on_nick_taken);
$conn->add_global_handler([ 251,252,253,254,302,255 ], \&on_init);
$conn->add_global_handler('disconnect', \&on_disconnect);
$conn->add_global_handler([ 353, 366 ], \&on_names);
$conn->add_global_handler(474,\&banned);
$conn->add_handler('msg',    \&on_msg);
$conn->add_handler('kick',\&on_kick);
$conn->add_handler('public', \&on_public);
$conn->add_handler('cversion',  \&on_version);
$conn->add_handler('cping', \&on_ping);
$conn->add_handler('join',   \&on_join);
$conn->add_handler('part',   \&on_part);
$conn->add_handler('quit',   \&on_part);
$conn->add_handler('nick',   \&on_nick);

#Connect
$irc->start;

#It's a habbit of mine putting this here
exit;


