#!/usr/bin/perl -w
################################################################################
# LICENSE
#-------------------------------------------------------------------------------
# Copyright (c) 2002 Shaun Guth
# 
# This file is part of PipSqueek
#
# PipSqueek is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# PipSqueek is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with PipSqueek; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#_______________________________________________________________________________


################################################################################
# INCLUDES / USE DIRECTIVES
#-------------------------------------------------------------------------------
use strict;			# Perl pragma to restrict unsafe constructs
use POE;			# Perl application kernel w/event driven threads
use POE::Component::IRC;	# A fully event-driven IRC client module
use LWP::Simple;		# Http client commands
use XML::Simple;		# Trivial API for reading and writing XML
#_______________________________________________________________________________


################################################################################
# GLOBAL VARIABLES
#-------------------------------------------------------------------------------
my $debug = $ARGV[0] || 0; # set to 2 if you want IRC rawcode to be spit out too

my %session_registry;	# POE session registry
			# this bot should never have more than one element

my %handler_registry;	# the handlers we have loaded up - so we can drop the
			# ones that we no longer use during a rehash

my %handler_helptext;	# help messages for each handler; these are loaded from
			# the very last line in a handler file.

my $bot;		# hash reference to our bot (XML::Simple load)
my $users;		# hash reference to users data (XML::Simple load)
#_______________________________________________________________________________



################################################################################
# SIGNAL HANDLERS
#-------------------------------------------------------------------------------
sub HUP_handler
{
	&rehash();
}
$SIG{'HUP'} = 'HUP_handler';
#_______________________________________________________________________________



################################################################################
# PROGRAM ENTRY POINT
#-------------------------------------------------------------------------------

# initialize the user hash
&debug(q|Loading UserHash|);
if( !($users = XMLin('data/users.xml', keyattr => { 'user' => '+nick' }) ) )
{
	&fatal(q|FAILED_INIT_USERHASH|);
}

# initialize the bot information so we can connect right away
if( !($bot = XMLin('data/bot.xml', forcearray => [ 'channel' ] )) )
{
	&fatal('FAILED_BOT_LOAD');
}

# initialize our POE IRC session
&debug(q|Creating POE IRC Session|);
POE::Component::IRC->new( 'pipsbot' ) or &fatal(qq|FAILED_INIT_POE_COMPONENT_IRC|);

# initialize our main POE session
&debug(q|Initializing main POE session|);

POE::Session->new(
	'main'	=>	[qw|
			_start
			_stop
			save
			lagcheck
			|]
);

&rehash();

# and away we go!
&debug(q|Running POE kernel|);
$poe_kernel->run();

exit;
#_______________________________________________________________________________



################################################################################
# some boring subroutines beyond this point ####################################
################################################################################

################################################################################
# Sets a certain key to the value on every user (do the hokey pokey!)
#
# accepts: key, value
# returns: 1
# 
#-------------------------------------------------------------------------------
sub user_set_all
{
	my ($key,$value) = @_;
	foreach my $nick ( keys %{$users->{'user'}} )
	{
		$users->{'user'}->{$nick}->{$key} = $value;
	}
	return 1;
}
#_______________________________________________________________________________


################################################################################
# Sets the key to the value on a specific user (or cnick)
#  
# accepts: nick, key, value
# returns: 1
# 
#-------------------------------------------------------------------------------
sub user_set
{
	my ($nick,$key,$value) = @_;

	my $nick2set = $nick;
	unless( exists( $users->{'user'}->{$nick} ) )
	{
		# get their alternate nick
		my $hash = &user_get_all_match_keys({'cnick' => $nick});
		foreach (keys %{$hash})
		{
			$nick2set = $users->{'user'}->{$_}->{'nick'};
		}
	}

	if( exists( $users->{'user'}->{$nick2set} ) )
	{
		if( ref($key) eq 'HASH' )
		{
			foreach my $setkey ( keys %{$key} )
			{
				$users->{'user'}->{$nick2set}->{$setkey} = $key->{$setkey};
			}
		}
		else
		{
			$users->{'user'}->{$nick2set}->{$key} = $value;
		}
	}

	return 1;
}
#_______________________________________________________________________________


################################################################################
# gets the value of the key of the user (or cnick)
#  
# accepts: nick, key
# returns: undef or value
# 
#-------------------------------------------------------------------------------
sub user_get
{
	my ($nick,$key) = @_;
	
	my $nick2get = $nick;
	unless( exists( $users->{'user'}->{$nick} ) )
	{
		my $hash = &user_get_all_match_keys({'cnick' => $nick});
		
		foreach (keys %{$hash})
		{
			$nick2get = $users->{'user'}->{$_}->{'nick'};
		}
	}
	
	if( exists( $users->{'user'}->{$nick2get} ) )
	{
		return $users->{'user'}->{$nick2get}->{$key};
	}
}
#_______________________________________________________________________________


################################################################################
# Returns a user hash of all users that have certain keys set to certain values
#-------------------------------------------------------------------------------
sub user_get_all_match_keys
{
	my ($keyhash) = @_;
	my %outbound;

	foreach my $nick ( keys %{ $users->{'user'} } )
	{
		my $add = 1;
		foreach my $key ( keys %{$keyhash} )
		{
			unless( $users->{'user'}->{$nick}->{$key} eq $keyhash->{$key} )
			{
				$add = 0;
			}
		}

		if( $add )
		{
			$outbound{ $nick } = $users->{'user'}->{$nick};
		}
	}

	return \%outbound;
}
#_______________________________________________________________________________



################################################################################
# Reloads and re-registers all commands this session handles
# 
# accepts: nothing
# returns: nothing
# 
#-------------------------------------------------------------------------------
sub rehash
{
	&debug( '(Re)Loading event handlers' );
	# load all our command handlers
	foreach my $s (keys %session_registry)
	{
		# reset the command handler registry
		$handler_registry{$_} = 0 foreach (keys %handler_registry);
		delete $handler_helptext{$_} foreach (keys %handler_helptext);

		#---------------------------------------------------------------
		# IRC event handlers
		opendir( DIR, 'handlers/rfc1459' ) or &debug( "Failed opening handlers/rfc1459/" );
		my @rfc_files = map "handlers/rfc1459/$_", sort grep !/^\.\.?|CVS$/, readdir DIR;
		closedir( DIR );

		foreach my $filename (@rfc_files) {
			my $command = 'irc_'.$filename;
			$command =~ s|handlers/rfc1459/||;
			
			&debug( "Compiling $command" );
			open( FILE, $filename ); my @contents = <FILE>; close( FILE );
			
			my $function;
			if( eval( '$function = ' . (join('',@contents)) ) )
			{
				$session_registry{$s}->register_state( $command, $function );
				$handler_registry{$command} = 1;
			}
			else
			{
				&debug("FAILED!! " . $@ );
				$handler_registry{$command} = 1 if exists $handler_registry{$command};
			}

			foreach my $line (@contents) {
				if( $line =~ /^# ~/ ) {
					$line =~ s/^# ~ //;chomp($line);
					push( @{$handler_helptext{$command}}, $line );
				}
			}
		}
		#---------------------------------------------------------------


		#---------------------------------------------------------------
		# ADMIN event handlers
		opendir( DIR, 'handlers/admin' ) or &debug( "Failed opening handlers/admin/" );
		my @admin_files = map "handlers/admin/$_", sort grep !/^\.\.?|CVS$/, readdir DIR;
		closedir( DIR );

		foreach my $filename (@admin_files) {
			my $command = 'admin_'.$filename;
			$command =~ s|handlers/admin/||;
			
			&debug( "Compiling $command" );
			open( FILE, $filename ); my @contents = <FILE>; close( FILE );
			
			my $function;
			if( eval( '$function = ' . (join('',@contents)) ) )
			{
				$session_registry{$s}->register_state( $command, $function );
				$handler_registry{$command} = 1;
			}
			else
			{
				&debug("FAILED!! " . $@ );
				$handler_registry{$command} = 1 if exists $handler_registry{$command};
			}

			foreach my $line (@contents) {
				if( $line =~ /^# ~/ ) {
					$line =~ s/^# ~ //;chomp($line);
					push( @{$handler_helptext{$command}}, $line );
				}
			}
		}
		#---------------------------------------------------------------


		#---------------------------------------------------------------
		# PRIVMSG event handlers
		opendir( DIR, 'handlers/private' ) or &debug( "Failed opening handlers/private/" );
		my @prv_files = map "handlers/private/$_", sort grep !/^\.\.?|CVS$/, readdir DIR;
		closedir( DIR );

		foreach my $filename (@prv_files) {
			my $command = 'private_'.$filename;
			$command =~ s|handlers/private/||;
			
			&debug( "Compiling $command" );
			open( FILE, $filename ); my @contents = <FILE>; close( FILE );
			
			my $function;
			if( eval( '$function = ' . (join('',@contents)) ) )
			{
				$session_registry{$s}->register_state( $command, $function );
				$handler_registry{$command} = 1;
			}
			else
			{
				&debug("FAILED!! " . $@ );
				$handler_registry{$command} = 1 if exists $handler_registry{$command};
			}

			foreach my $line (@contents) {
				if( $line =~ /^# ~/ ) {
					$line =~ s/^# ~ //;chomp($line);
					push( @{$handler_helptext{$command}}, $line );
				}
			}
		}
		#---------------------------------------------------------------


		#---------------------------------------------------------------
		# PUBLIC event handlers
		opendir( DIR, 'handlers/public' ) or &debug( "Failed opening handlers/public/" );
		my @pub_files = map "handlers/public/$_", sort grep !/^\.\.?|CVS$/, readdir DIR;
		closedir( DIR );

		foreach my $filename (@pub_files) {
			my $command = 'public_'.$filename;
			$command =~ s|handlers/public/||;
			
			&debug( "Compiling $command" );
			open( FILE, $filename ); my @contents = <FILE>; close( FILE );
			
			my $function;
			if( eval( '$function = ' . (join('',@contents)) ) )
			{
				$session_registry{$s}->register_state( $command, $function );
				$handler_registry{$command} = 1;
			}
			else
			{
				&debug("FAILED!! " . $@ );
				$handler_registry{$command} = 1 if exists $handler_registry{$command};
			}

			foreach my $line (@contents) {
				if( $line =~ /^# ~/ ) {
					$line =~ s/^# ~ //;chomp($line);
					push( @{$handler_helptext{$command}}, $line );
				}
			}
		}
		#---------------------------------------------------------------


		# drop all commands we don't have a command for anymore
		foreach (keys %handler_registry)
		{
			if( $handler_registry{$_} == 0 ) {
				delete $handler_registry{$_};
				delete $handler_helptext{$_};
				$session_registry{$s}->register_state( $_ );
			}
		}
	}
	
	# reload the bot configuration
	if( !($bot = XMLin('data/bot.xml', forcearray => ['channel'] )) )
	{
		&fatal('FAILED_BOT_LOAD');
	}
}
#_______________________________________________________________________________
	
	
################################################################################
# Issues the connect command
#
# accepts: POE Kernel
# returns: nothing
#
#-------------------------------------------------------------------------------
sub connect_to_irc
{
	my $kernel = shift;
	# set up our IRC connection
	&debug('Connecting to ' . $bot->{'server'}->{'host'} . ':' . $bot->{'server'}->{'port'});

	# Setting Debug to 1 causes POE::Component::IRC to print all raw lines
	# of text sent to and receive from the IRC server.
	# Very useful for debugging
	$kernel->post( 'pipsbot', 'connect', 
		{
			'Debug'		=>	( $debug == 2 ? 1 : 0 ),
			'Nick'		=>	$bot->{'info'}->{'nick'},
			'Username'	=>	$bot->{'info'}->{'user'},
			'Ircname'	=>	$bot->{'info'}->{'name'},
			'Server'	=>	$bot->{'server'}->{'host'},
			'Port'		=>	$bot->{'server'}->{'port'},
		}
	);
}
#_______________________________________________________________________________


################################################################################
# Flushes our user data out to the file
#-------------------------------------------------------------------------------
sub save
{
	$_[HEAP]->{next_alarm_time} += 300;
	$_[KERNEL]->alarm( save => $_[HEAP]->{next_alarm_time} );

	XMLout ( $users,   keyattr => { 'user' => '+nick' }, outputfile => 'data/users.xml' );
	XMLout ( $bot, outputfile => 'data/bot.xml' );
}
#_______________________________________________________________________________


################################################################################
# Pings the server every 2 minutes, to help keep the bot alive 
#-------------------------------------------------------------------------------
sub lagcheck
{
	$_[HEAP]->{next_lagalarm_time} += 180;
	$_[KERNEL]->alarm( lagcheck => $_[HEAP]->{next_lagalarm_time} );
	$_[KERNEL]->post( 'pipsbot', 'sl', 'PING ' . time() );
}
#_______________________________________________________________________________


################################################################################
# Every POE session must handle a special event, _start.  It's used to tell the
# session that it has been successfully instantiated.
# 
# accepts:
# $_[KERNEL]	- a reference to the program's global POE::Kernel instance
# $_[SESSION]	- a reference to the session itself
# 
# returns:	1 on success
# 		0 on failure
# 		
#-------------------------------------------------------------------------------
sub _start
{
	my ($kernel,$session) = @_[KERNEL, SESSION];
	&debug('Session ' . $session->ID . ' has started.');
	
	# register our session
	$session_registry{ $_[SESSION]->ID() } = $_[SESSION];

	# Uncomment this to turn on more verbose POE debugging information.
	# (not normally used, but jic something is totally b0rked
	#$session->option( trace => 1 );

	# Make an alias for our session, to keep it from getting GC'ed
	$kernel->alias_set( 'pips' );

	# Ask the IRC component to send us all IRC events it receives.
	# This is the easy indiscriminate way to do it
	$kernel->post( 'pipsbot', 'register', 'all' );

	# connect the bot
	&connect_to_irc($kernel);

	# tell the kernel we want to save our users database every 5 minutes
	$_[HEAP]->{next_alarm_time} = int(time()) + 300;
	$kernel->alarm( save => $_[HEAP]->{next_alarm_time} );

	# we also ping the server periodically, to keep our bot alive (was timing
	# out for unknown reasons )
	$_[HEAP]->{next_lagalarm_time} = int( time() ) + 180;
	$kernel->alarm( lagcheck => $_[HEAP]->{next_lagalarm_time} );

	return 1;
}
#_______________________________________________________________________________


################################################################################
# The POE _stop event is special but, handling it is not required.
# It is used to tell a session that it is about to be destroyed.  _stop handlers
# perform shutdown things like resource cleanup or termination logging.
#
# accepts:
# $_[KERNEL]	- a reference to the program's global POE::Kernel instance
# $_[SESSION]	- a reference to the session itself
# returns:	1 on success
# 		0 on failure
#
#-------------------------------------------------------------------------------
sub _stop
{
	my ($kernel,$session) = @_[KERNEL, SESSION];

	$kernel->post( 'pipsbot', 'quit', 'PipSqueek v2.0  http://pipsqueek.l8nite.net/' );
	$kernel->alias_remove( 'pips' );

	# unregister
	delete $session_registry{ $_[SESSION]->ID() };
	
	&debug('Session ' . $session->ID . ' has stopped.');
}
#_______________________________________________________________________________


################################################################################
# Sends the argument passed in to STDOUT if the $debug flag is set
#
# accepts:	the message to print
# returns:	1 always
#_______________________________________________________________________________
sub debug
{
	my $msg = shift;
	print "$msg\n" if $debug;
}
#_______________________________________________________________________________


################################################################################
# dies with the argument passed
# # could be extended in the future to add logging or provide troubleshooting
#
# accepts:	the type of error that occured
# returns:	nothing
#_______________________________________________________________________________
sub fatal
{
	my $type = shift;
	die (qq|Fatal Error Type: $type|);
}
#_______________________________________________________________________________


exit; # just in case something messes up and code evals to the end here

