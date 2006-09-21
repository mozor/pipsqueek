#
# PipSqueek install script - Adds a new bot
#

use l8nite::mysql;

my ($sql) = new l8nite::mysql;

my $db_name;
my $db_user;
my $db_pass;
my( $bot_id, $script_name, $workingdir );

MAIN:
{
	print "Welcome to the bot creator!\n\n";

	my ($bot_nickname);
	print "What would you like your bots name to be?\n";
	print "(PipSqueek): ";
	chomp( $bot_nickname = <STDIN> );
	$bot_nickname = "PipSqueek" if $bot_nickname eq "";


	my ($bot_nickpass);
	print "What should this bots nickserv password be?\n";
	print ": ";
	chomp( $bot_nickpass = <STDIN> );

	die print "The bot must have a nickserv password!\n" if $bot_nickpass eq "";


	my ($server_name);
	print "What IRC network server should the bot connect to?\n";
	print "(irc.observers.net): ";
	chomp( $server_name = <STDIN> );
	$server_name = "irc.observers.net" if $server_name eq "";


	my ($server_port);
	print "What port does this IRC network use?\n";
	print "(6667): ";
	chomp( $server_port = <STDIN> );
	$server_port = "6667" if $server_port eq "";


	my ($bot_channel);
	print "What channel should the bot be in?\n";
	print "(#nowhere): ";
	chomp( $bot_channel = <STDIN> );
	$bot_channel = "#nowhere" if $bot_channel eq "";


	print "Does this bot have a vhost?\n";
	print "(no): ";
	chomp( $answer = <STDIN> );
	$answer = "no" if $answer eq "";

	my( $vhost_username, $vhost_password );

	if( $answer =~ m/y/gi )
	{
		print "Hey that's pretty cool!\n";
		print "What's the vhost username?\n";
		print ": ";
		chomp( $vhost_username = <STDIN> );

		die print "You must have a vhost username!\n" if $vhost_username eq "";

		print "and the password?\n";
		print ": ";
		chomp( $vhost_password = <STDIN> );

		die print "The vhost must have a password!\n" if $vhost_password eq "";
	}


	my ($authpass);
	print "What password would you like for the remote command interface?\n";
	print ": ";
	chomp( $authpass = <STDIN> );
	
	die print "You must have a remote command password!\n" if $authpass eq "";

	my ($des_salt);
	print "Choose a 2-character (alphanumerics) salt for your author password\n";
	print "(7e): ";
	chomp( $des_salt = <STDIN> );
	$des_salt = "7e" if $des_salt eq "";

	$authpass = crypt( $authpass, $des_salt );

	my ($command_prefix);
	print "What public command prefix would you like?\n";
	print "(!): ";
	chomp( $command_prefix = <STDIN> );
	$command_prefix = "!" if $command_prefix eq "";


	my ($command_flood_limit);
	print "What should the command flood limit be? (1 command every X seconds)\n";
	print "(3): ";
	chomp( $command_flood_limit = <STDIN> );
	$command_flood_limit = 3 if $command_flood_limit eq "";

	
	my ($cpp);
	print "How many characters typed should equal a point?\n";
	print "(100): ";
	chomp( $cpp = <STDIN> );
	$cpp = 100 if $cpp eq "";

	my ($usd);
	print "Should the bot use spam detection?\n";
	print "(yes): ";
	chomp( $usd = <STDIN> );
	if ( $usd ne "" )
	{
		if( $usd =~ m/y/gi ){ $usd = 1; } else { $usd = 0; }
	}else{ $usd = 1; }

	my ($spampen);
	print "What should the penalty be for spamming? (X char deduction per spam letter)\n";
	print "(10): ";
	chomp( $spampen = <STDIN> );
	$spampen = 10 if $spampen eq "";


	my ($ufd);
	print "Should the bot use flood detection?\n";
	print "(yes): ";
	chomp( $ufd = <STDIN> );
	if ( $ufd ne "" )
	{
		if( $ufd =~ m/y/gi ){ $ufd = 1; } else { $ufd = 0; }
	}else{ $ufd = 1; }

	my( $ctcp_fl, $ctcp_fs );
	my( $priv_fl, $priv_fs );
	my( $publ_fl, $publ_fs );
	my ($floodpen);

	if( $ufd == 1 )
	{


		print "What is the lines per second for CTCP?\n";
		print "(3/2): ";
		chomp( $answer = <STDIN> );
		if ( $answer eq "" )
		{
			($ctcp_fl, $ctcp_fs) = (3,2);
		}else{
			($ctcp_fl,$ctcp_fs) = split( /\//, $answer );
		}


		print "What is the lines per second for private messages?\n";
		print "(4/2): ";
		chomp( $answer = <STDIN> );
		if ( $answer eq "" )
		{
			($priv_fl, $priv_fs) = (3,2);
		}else{
			($priv_fl,$priv_fs) = split( /\//, $answer );
		}


		print "What is the lines per second for public channel text?\n";
		print "(6/4): ";
		chomp( $answer = <STDIN> );
		if ( $answer eq "" )
		{
			($publ_fl, $publ_fs) = (3,2);
		}else{
			($publ_fl,$publ_fs) = split( /\//, $answer );
		}


		print "What should the penalty be for flooding? (X char deduction per flood line)\n";
		print "(400): ";
		chomp( $floodpen = <STDIN> );
		$floodpen = 400 if $floodpen eq "";
	}

	my ($eliza);
	print "Do you want eliza (chatbot) mode enabled by default?\n";
	print "(no): ";
	chomp( $answer = <STDIN> );
	if ( $answer ne "" )
	{
		if( $answer =~ m/y/gi ){ $eliza = 1; } else { $eliza = 0; }
	}else{ $eliza = 0; }


	print "Ok, looks like we're all set up, attempting to read the database configuration\n";
	&loadConfigurationFile( "database.conf" );

	$sql->connectDB( $db_name, $db_user, $db_pass );

	print "Adding the new bot info...\n";

	$sql->ocQuery( qq~INSERT INTO bots( bot_id, process_id, server_name, server_port, vhost_username, vhost_password, channel, nickname, nickserv_password, control_password, des_salt, language_id, command_prefix, command_flood_limit, chars_per_point, use_spam_detection, spam_penalty, use_flood_detection, ctcp_flood_lines, ctcp_flood_seconds, private_flood_lines, private_flood_seconds, public_flood_lines, public_flood_seconds, flood_penalty, eliza_mode ) VALUES ( 0, 999999, "$server_name", "$server_port", "$vhost_username", "$vhost_password", "$bot_channel", "$bot_nickname", "$bot_nickpass", "$authpass", "$des_salt", 1, "$command_prefix", $command_flood_limit, $cpp, $usd, $spampen, $ufd, $ctcp_fl, $ctcp_fs, $priv_fl, $priv_fs, $publ_fl, $publ_fs, $floodpen, $eliza )~ );

	&loadConfigurationFile( "bot.conf" );

	print "OWNED: $script_name\n";
	print "OWNED: $workingdir\n";

	my ($newbotid) = $sql->oneShot( qq~SELECT bot_id FROM bots WHERE nickname="$bot_nickname" AND channel="$bot_channel"~ );


	open( OUTF, ">bot.conf" ) or die print "Could not open bot.conf for writing!!\n";
	print OUTF "\$workingdir = \"$workingdir\";\n";
	print OUTF "\$script_name = \"$script_name\";\n";
	print OUTF "\$bot_id = $newbotid;\n";
	close( OUTF );


	print "Hey!!! You're all done!\n";
	print "To run your new bot type 'perl $script_name' without the quotes\n";
	print "\n";
	print "Installer written by l8nite - pipsqueek\@l8nite.net\n\n";
	
	$sql->disconnectDB();

}




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
