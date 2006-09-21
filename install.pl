#
# Install script for PipSqueek
#
push( @INC, "." );

use l8nite::mysql;

my ($sql) = new l8nite::mysql;

MAIN:
{
	my ($name);
	my ($root_sql_password);

	print "------------------------------------\n";
	print "   PipSqueek v1.2.2-mysql install   \n";
	print "------------------------------------\n";
	print "\n";

	print "What's your name?\n";
	print ": ";
	chomp( $name = <STDIN> );
	$name = "anonymous" if $name eq "";

	my ($workingdir, $scriptname);
	print "What's this directory name?\n";
	print ": ";
	chomp( $workingdir = <STDIN> );

	die print "Must have a working dir for script\n" if $workingdir eq "";

	print "What's the PipSqueek script name?\n";
	print "(PipSqueek.pl): ";
	chomp( $scriptname = <STDIN> );
	$scriptname = "PipSqueek.pl" if $scriptname eq "";


	my ($db_name);
	print "What would you like the database name to be?\n";
	print "(pipsqueek): ";
	chomp( $db_name = <STDIN> );
	$db_name = "pipsqueek" if( $db_name eq "" );


	my ($db_user);
	print "What username do you want for the $db_name database?\n";
	print "(pips): ";
	chomp( $db_user = <STDIN> );
	$db_user = "pips" if $db_user eq "";


	my ($db_pass);
	print "What password do you want for username $db_user?\n";
	print ": ";
	chomp( $db_pass = <STDIN> );

	die print "The database user must have a password!\n" if $db_pass eq "";


	my ($answer);
	print "Do you need me to create the database and user for you?\n";
	print ": ";
	chomp( $answer = <STDIN> );
	if( $answer =~ m/y/gi )
	{
		print "Ok, attempting to create the database and user...\n";

		print "$name, what is the root password for your mysql database?\n";
		print ": ";
		chomp( $root_sql_password = <STDIN> );

		die print "You must supply the root mysql password!\n" if $root_sql_password eq "";
	
		$sql->connectDB( 'mysql', 'root', $root_sql_password );
		$sql->ocQuery( qq~CREATE DATABASE $db_name~ );
		$sql->ocQuery( qq~GRANT ALL PRIVILEGES ON $db_name.* TO ${db_user}\@localhost~ );
		$sql->ocQuery( qq~UPDATE user SET password=PASSWORD("$db_pass") WHERE user="$db_user"~ );
		$sql->disconnectDB();

		print "Hey thanks $name, you're doing great.\n";
		print "Before we can continue you'll need to restart the mysql service\n";
		$answer = "No";
		while( $answer !~ m/y/gi )
		{
			print "Have you restarted it? ";
			chomp( $answer = <STDIN> );
		}
	}

	print "Fantastic, attempting to create the database tables now\n";

	$sql->connectDB( $db_name, $db_user, $db_pass );
	$sql->ocQuery( qq~CREATE TABLE users ( user_id int not null primary key auto_increment, username varchar(255) not null, real_username varchar(255) not null, ident varchar(255) not null, password varchar(255) not null, last_seen datetime null, active tinyint(1) not null default 1, score int not null default 0, enemy tinyint(1) not null default 0, flood int not null default 0, linecount int not null default 0, bot_id int not null )~ );
	print "users table created...\n";
	$sql->ocQuery( qq~CREATE TABLE bots ( bot_id int not null primary key auto_increment, process_id int not null, server_name varchar(255) not null, server_port int(5) not null default 6667, vhost_username varchar(255), vhost_password varchar(255), channel varchar(255) not null, nickname varchar(255) not null, nickserv_password varchar(255), control_password varchar(255) not null, des_salt varchar(2) not null, language_id int not null default 0, command_prefix varchar(255) not null, command_flood_limit int not null default 3, chars_per_point int not null default 100, use_spam_detection tinyint(1) not null default 1, spam_penalty int not null default 10, use_flood_detection tinyint(1) not null default 1, ctcp_flood_lines int not null default 3, ctcp_flood_seconds int not null default 2, private_flood_lines int not null default 4, private_flood_seconds int not null default 2, public_flood_lines int not null default 6, public_flood_seconds int not null default 4, flood_penalty int not null default 400, eliza_mode int not null default 0 )~ );
	print "bots table created...\n";
	$sql->ocQuery( qq~CREATE TABLE languages ( language_id int not null primary key auto_increment, name varchar(255) not null, greeting varchar(255) not null, score_report varchar(255) not null, score_error varchar(255) not null, rank_report varchar(255) not null, rank_error varchar(255) not null, score_top10 varchar(255) not null, add_to_db varchar(255) not null, command_delay varchar(255) not null, spam_detected varchar(255) not null, flood_detected varchar(255) not null, restart varchar(255) not null, reload_config varchar(255) not null, cycle varchar(255) not null, score_change varchar(255) not null, seen_found varchar(255) not null, seen_notfound varchar(255) not null, seen_yourself varchar(255) not null, seen_onchannel varchar(255) not null, bot_selfscore varchar(255) not null, bot_selfseen varchar(255) not null, language_changed varchar(255) not null, eliza varchar(255) not null )~ );
	print "language table created...\n";
	$sql->ocQuery( qq~CREATE TABLE kick_messages ( rowid int not null primary key auto_increment, bot_id int not null, message varchar(255) not null )~ );
	print "kick_messages table created...\n";
	$sql->ocQuery( qq~CREATE TABLE quotes ( rowid int not null primary key auto_increment, bot_id int not null, message varchar(255) not null )~ );
	print "quotes table created...\n";
	$sql->ocQuery( qq~CREATE TABLE flood_check ( rowid int not null primary key auto_increment, bot_id int not null, username varchar(255) not null, type varchar(255) not null, time datetime not null )~ );
	print "flood_check table created...\n";
	print "That's all the tables, phew ;)\n\n";
	$sql->disconnectDB();

	print "Saving configuration...\n";
	open( OUTF, ">database.conf" ) or die print "Could not open database.conf for writing!!\n";

	print OUTF "\$db_name = \"$db_name\";\n";
	print OUTF "\$db_user = \"$db_user\";\n";
	print OUTF "\$db_pass = \"$db_pass\";\n";

	close( OUTF );

	open( OUTF, ">bot.conf" ) or die print "Could not open bot.conf for writing!!\n";
	print OUTF "\$workingdir = \"$workingdir\";\n";
	print OUTF "\$script_name = \"$scriptname\";\n";
	print OUTF "\$bot_id = 1;\n";
	close( OUTF );


	$sql->connectDB( $db_name, $db_user, $db_pass );
	print "------------------------------------\n";
#	print "Would you like the bot to use the default language?\n";
#	print "(yes): ";
#	chomp( $answer = <STDIN> );

#	if( $answer eq "" || $answer =~ m/y/gi )
#	{
		$sql->ocQuery( qq~INSERT INTO languages VALUES (1,'American','Hey there ::name::!','::name::\\\'s score is ::score:: point::plural::','::name::\\\'s score is non-existent','Rank ::rank::: ::name:: (::score::)','<name>::name::\\\'s rank was not found.</name><rank>No user could be found with rank ::rank::</rank>','<intro>Top10: </intro>::name:: (::score::)<notfinal>, </notfinal><outtro>!</outtro>','Ahoy ::person:: [you have been added]','Please wait ::seconds:: second::plural::','<b>::name:::</b> ::deduction:: point::plural:: were deducted from your score for spamming','<b>::name:::</b> ::deduction:: point::plural:: were deducted from your score for flooding','Restarting (issued by ::person::)','Configuration file reloaded (issued by ::person::)','Cycling channel...','::person:: changed ::name::\\\'s score from ::oldscore:: to ::newscore:: (::increment::)','::name:: was last seen<notzero> ::days:: days,</notzero><notzero> ::hours:: hours</notzero><notzero> ::minutes:: minutes and</notzero> ::seconds:: seconds ago','I have not seen ::name:: in this channel','Looking for yourself, eh ::name::?','::name:: is currently on ::channel::','heh, newbie.','Never ph33r, I, is here.','::person:: changed my language from ::oldlanguage:: to ::newlanguage::','Eliza mode is now <b>::status::</b>')~ );
#	}
#	else
#	{
#		print "This is gonna be brutal... :/\n";
#		print "As a matter of fact, it's not supported by the install script yet\n";
#		die;
#		exec( "perl addlanguage.pl" );
#	}

	print "Would you like to install the default quotes files? (~240 quotes!)\n";
	print "(yes): ";
	chomp( $answer = <STDIN> );

	if( $answer eq "" || $answer =~ m/y/gi )
	{
		print "Installing quotes...\n";
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (1,1,'\"What the fuck was that?\"  Mayor of Hiroshima\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (2,1,'\"Thats not a real fucking gun.\"  John Lennon\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (3,1,'\"Who\\\'s gonna fucking find out?\"  Richard Nixon\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (4,1,'\"Heads are going to fucking roll.\"    Anne Boleyn\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (5,1,'\"What fucking map?\"   Mark Thatcher\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (6,1,'\"Any fucking idiot could understand that.\"  Albert Einstein\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (7,1,'\"It does so fucking look like her!\"  Picasso\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (8,1,'\"How the fuck did you work that out?\"  Pythagoras\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (9,1,'\"You want what on the fucking ceiling?\"  Michaelangelo\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (10,1,'\"Fuck a duck.\"   Walt Disney\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (11,1,'\"Why?- Because its fucking there!\"  Edmund Hilary\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (12,1,'\"I don\\\'t suppose its gonna fucking rain?\"   Joan of Arc\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (13,1,'\"Scattered fucking showers my ass.\"   Noah\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (14,1,'\"Let the fucking woman drive.\"  Commander of Space Shuttle \"Challenger\"\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (15,1,'\"Where did all these fucking Indians come from?\"  General Custer\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (16,1,'\"Where the fuck is all this water coming from?\"   Captain of the Titanic\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (17,1,'\"I need this parade like I need a fucking hole in my head.\"  John F. Kennedy\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (18,1,'\"And now for something completely different!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (19,1,'\"It\\\'s...\"\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (20,1,'Despite the cost of living, have you noticed how popular it remains?  - Erm\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (21,1,'\"You mean spam, spam, spam, spam, spam, spam, spam, spam, spam, smam, spam, and spam?\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (22,1,'<Astarath> I can break into stores easily because i have a glass-cutter on my groin\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (23,1,'\"It\\\'s not pining, it\\\'s passed on! This parrot is no more! It has ceased to be! It\\\'s expired and gone to meet it\\\'s maker! This is a late parrot! It\\\'s a stiff! Bereft of life, it rests in peace!')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (24,1,'\"A shroe, a shroe, my dingkom for a shroe.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (25,1,'\"This is Mr. E. R. Bradsaw. He cannot be seen. Mr. Bradsaw, will you stand up please?...BANG...This demonstrates the value of not being seen.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (26,1,'\"The goal of this year\\\'s expedition is to see if we can find any traces of last year\\\'s expedition. My brother was leading that. They were going to build a bridge between the two peaks...\"\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (27,1,'<LtKer_Astarath> i make my own pr0n with a hex editor\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (28,1,'\"Australia, Australia, Australia, Australia, we love you. Amen.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (29,1,'\"My brain hurts!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (30,1,'\"Les voyageurs, les bagages! Ils sont...ici!\" (The passengers, the luggage! They are...here!) \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (31,1,'\"I give you, on the mouse organ, The Bells of St. Mary!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (32,1,'\"Nobody expects the Spanish Inquisition!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (33,1,'\"And Oliver has run himself over, what a great twit!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (34,1,'\"Bally Jerry pranged his kite right in the how\\\'s-your-father. Harry Blighter dicky-birdied, feathered back on his sammy, took a waspy, flipped over on his Betty Harper\\\'s, and caught his can in the birdie!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (35,1,'\"Hand over all the lupines you\\\'ve got!\"\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (36,1,'Menstruation: a bloody waste of time\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (37,1,'\"By avoiding wood and timber derivitives, we have almost totally removed the risk of...(SATIRE)...quite frankly, I think the central pillar system may need strengthening a bit.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (38,1,'\"I\\\'d like to have an argument, please.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (39,1,'\"Danish bimbo, Chzech sheep\\\'s milk, Venezualan beaver cheese?\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (40,1,'<Ac1dfl4sh> if my brain was as big as my penis my head would explode\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (41,1,'\"What do you mean, an African or European swallow?\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (42,1,'\"You don\\\'t frighten us, English pig-dogs! Go and boil your bottoms, sons of a silly person! I blow my nose at you, so-called Arthur king! You and all your silly English knnnniggits!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (43,1,'\"I don\\\'t wanna talk to you no more, you empty-headed animal food trough water! I fart in your general direction! Your mother was a hamster, and your father smelled of elderberries!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (44,1,'\"If we took the bones out it wouldn\\\'t be crunchy, would it?\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (45,1,'\"I\\\'m a lumberjack and I\\\'m okay, I sleep all night and I work all day!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (46,1,'\"First, take a bunch of flowers! Irises, freesias, pretty begonias, and chrymanthysums! Next, arrange them, nicely, in a vase! \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (47,1,'Applying computer technology is simply finding the right wrench to pound in the correct screw. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (48,1,'Metaphysics is a cobweb that the mind weaves around things. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (49,1,'We spend more time working for our labor-saving machines than they do working for us. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (50,1,'Bus Error - Please Take The Train. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (51,1,'In theory, there is no difference between theory and practice. In practice, there is a big difference. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (52,1,'I tell my students that artificial intelligence is a property that a machine has if it astounds you.   Herbert Freeman \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (53,1,'An elephant is a mouse with an operating system. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (54,1,'If it\\\'s not on fire then it\\\'s a software problem. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (55,1,'You know you\\\'ve been spending too much time on the Internet when every colon appears as a pair of eyes: (see what I mean?)   Erik \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (56,1,'As soon as you delete a worthless file, you\\\'ll need it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (57,1,'Installing a new program will always screw up at least one old one. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (58,1,'The computer will work perfectly at the repair shop. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (59,1,'The time it takes to clean up after a computer virus is inversely proportional to the time it took to do the damage. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (60,1,'The first place to look for a lost file is the last place you would expect to find it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (61,1,'Never cut what you can untie. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (62,1,'The trouble with experience as a teacher is that the test comes first and the lesson after. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (63,1,'Any sufficient advanced technology is indistinguishable from magic.   Arthur C. Clarke \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (64,1,'The floppy will be the wrong size. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (65,1,'Survive first, then do the long-term planning \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (66,1,'Important letters that contain no errors will develop errors on the way to the printer \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (67,1,'Regardless of the size of the program, you won\\\'t have enough hard disk space to install it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (68,1,'You\\\'ll never have enough time, money, or memory. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (69,1,'Whatever hits from the fan will not evenly distribute \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (70,1,'Anything that can go wrong, will go wrong. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (71,1,'It works better if you plug it in. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (72,1,'You almost work better if you don\\\'t. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (73,1,'When trying to solve a problem, it always helps to know the solution. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (74,1,'The easier it is to get into a program, the harder it will be to get out. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (75,1,'To err is human, but it takes a computer to really screw things up. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (76,1,'At the source of every error blamed on the computer, you will find at least two errors, including the error of blaming it on the computer. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (77,1,'The squeaky wheel gets the grease. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (78,1,'There\\\'s an easier way to do anything. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (79,1,'Every machine will eventually fall apart. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (80,1,'If it jams, force it. If it breaks, it needed to be replaced anyway. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (81,1,'You can never be too rich, too thin, or have too much memory. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (82,1,'Any simple idea will be worded in the most complicated way. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (83,1,'If you hit two keys on the keyboard, the one you don\\\'t want will appear on the screen. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (84,1,'No matter how long you shop for an item, after you\\\'ve bought it, it will be on sale cheaper. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (85,1,'All probabilities are 50 percent. Either a thing will happen or it won\\\'t. Odds, however, are 90 percent against you. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (86,1,'The computer only crashes when printing a document you haven\\\'t saved. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (87,1,'Hot parts look exactly like cold parts. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (88,1,'The person who smiles when bad things happen knows who to blame it on. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (89,1,'If you make a copy of your system configuration nine out of ten times, the tenth time is the only time you will need it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (90,1,'The more pounds the package weighs, the harder it will be to find the installation instructions. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (91,1,'If the new software you want requires new hardware to run, you don\\\'t need the new software. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (92,1,'No matter how large the hard disk, the need for space will always exceed the available space by ten percent. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (93,1,'The likelihood of a hard disk crash is in direct proportion to the value of the material that hasn\\\'t been backed up. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (94,1,'There are only two kinds of computer users. Those whose hard disk has crashed and those whose hard disk hasn\\\'t crashed - yet. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (95,1,'Before you do anything, you have to do something else first. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (96,1,'If you don\\\'t care where you are, you\\\'re not lost. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (97,1,'Anything can be made to work if you fiddle with it long enough. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (98,1,'If you fiddle with something long enough, you\\\'ll break it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (99,1,'An expert is a person who avoid the small errors while sweeping on to the grand fallacy. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (100,1,'Facts are not all equal. There are good facts and bad facts. Science consists of using good facts. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (101,1,'Whatever goes wrong, there\\\'s always someone who knew it would. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (102,1,'You can\\\'t win them all, but you sure can lose them all. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (103,1,'It\\\'s a mistake to allow any mechanical object to know you\\\'re in a hurry. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (104,1,'If it\\\'s worth doing, it\\\'s worth hiring someone who know how to do it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (105,1,'An ounce of application is worth a ton of abstraction. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (106,1,'If builders built buildings the way programmer wrote programs, the first woodpecker that came along would destroy civilization. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (107,1,'The best way to have a good idea is to have a lot of ideas. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (108,1,'The incidence of typographical errors increases in proportion to the number of people who will see the copy. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (109,1,'The incidence of missed typographical errors is in direct proportion to the size of the letters in the copy. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (110,1,'The one piece of data you\\\'re absolutely sure is correct, isn\\\'t. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (111,1,'Typographical errors will be found only after the letter is mailed. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (112,1,'If you want to keep your head while all those about you are losing theirs, be in charge of the guillotine. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (113,1,'The attention span of a computer is only as long as its electrical cord. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (114,1,'The weaker the math, the more elaborate the graphics need to be. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (115,1,'Adding staff to a late project makes it later. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (116,1,'If something doesn\\\'t go wrong, in the end it will be shown that it would have been ultimately beneficial for it to have gone wrong. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (117,1,'There are no real secrets - only obfuscations. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (118,1,'When all else fails, read the instructions. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (119,1,'A computer program does what you tell it to do, not what you want it to do. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (120,1,'The most useless computer tasks are the most fun to do. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (121,1,'Software bugs are correctable only after the software is judged obsolete by the industry. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (122,1,'When putting it into memory, remember where you put it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (123,1,'Users don\\\'t know what they really want, but they know for certain what they don\\\'t want. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (124,1,'Program complexity grows until it exceeds the capability of the programmer who must maintain it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (125,1,'Interchangeable tapes won\\\'t. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (126,1,'Profanity is one language all programmers know best. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (127,1,'Computers are unreliable, but humans are even more unreliable. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (128,1,'Any system that depends on human reliability is unreliable. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (129,1,'Undetectable errors are infinite in variety, in contrast to detectable errors, which by definition are limited. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (130,1,'You can\\\'t win. You can\\\'t break even. You can\\\'t even quit the game. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (131,1,'Artificial Intelligence is no match for natural stupidity. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (132,1,'A transistor protected by a fast-acting fuse will protect the fuse by blowing first. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (133,1,'A failure will not appear until a unit has passed final inspection. A purchased component or instrument will meet its specs long enough, and only long enough, to pass inspection. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (134,1,'If wires can be connected in two different ways, the first way blows the fuse. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (135,1,'Ahh. You see that would never have happened under OS/2!    John Kahler \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (137,1,'Act in haste and repent at leisure; Code too soon and debug forever. Raymond Kennington \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (138,1,'If a thing is worth doing, it\\\'s worth doing well - unless doing it well takes so long that it isn\\\'t worth doing any more. Then you just do it \\\'good enough\\\'. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (139,1,'slyfx iz l33t -- l8nite\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (140,1,'DOS Computers are by far the most popular, with about 70 million machines in use wordwide. Macintosh fans, on the other hand, may note that cockroaches are far more numerous than humans as well')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (141,1,'Do not look into the laser with remaining eye! - warning message on the side of lab laser \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (142,1,'Applicants must also have extensive knowledge of Unix, although they should have sufficiently good programming taste to not consider this an achievement. Hal Abelson, MIT job advertisement. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (143,1,'Atilla The Hun\\\'s Maxim: If you\\\'re going to rape, pillage and burn, be sure to do things in that order.   P. J. Plauger, Programming On Purpose \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (144,1,'There is no reason for any individual to have a computer in their home.    Ken Olson, President of World Future Society Convention, 1977 \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (145,1,'Win 95 is Mac \\\'89.   Helge Tonsky \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (146,1,'This Windows 95 hairball has become so big, so unmanageable, so hard to use, so hard to configure, so hard to keep up and running, so hard to keep secure. Windows 95 is a great gift to give your kid this Christmas because it will keep your kid fascinated')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (147,1,'I have no mouth. And I must scream.   Harlan Ellison \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (148,1,'Who cares how it works, just as long as it gives the right answer.  Jeff Scholnik \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (149,1,'A.I. - the art of making computers behave like the ones in the movies \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (150,1,'640K ought to be enough for anybody.   -Bill Gates, in 1981 \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (151,1,'Cyberarmy was designed with Microsoft Notepad.\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (152,1,'Never test for an error condition you don\\\'t know how to handle. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (153,1,'One disk to rule them all,  One disk to bind them,  One disk to hold the files  And in the darkness grind \\\'em. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (154,1,'A transistor protected by a fast-acting fuse will protect the fuse by blowing first. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (156,1,'Beware of programmers who carry screwdrivers.    Leonard Brandwein \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (157,1,'Disc space - the final frontier! \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (158,1,'f u cn rd ths, u cn gt a gd jb n cmptr prgrmmng. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (159,1,'To some of us, reading the manual is conceding defeat.   Jason Q. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (160,1,'Doom should be an olympic sport.   Dave Goldberger \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (161,1,'The moving cursor writes, and having written, blinks on.\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (162,1,'Line printer paper is strongest at the perforations.\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (163,1,'Hardware:   This is the part of the computer that stops working when you spill beer on it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (164,1,'Software:   These programs give instruction to the CPU, which processes billions of tiny facts called bytes, and within a fraction of a second it sends you an error message that requires you to call the customer-support hot line and be placed on hold')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (165,1,'Megahertz:  This is really, really big hertz. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (166,1,'RAM:  This gives guys a way of deciding whose computer has the biggest, studliest memory. That\\\'s important, because the more memory a computer has, the faster it can produce error messages. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (167,1,'Internet:  is the single most important development in the history of human communications since the invention of call-waiting. A bold statement? Indeed, but consider how the internet can enhance our lives. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (169,1,'Cannot find REALITY.SYS. Universe halted. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (170,1,'Buy a Pentium 586/90 so you can reboot faster. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (171,1,'2 + 2 = 5 for extremely large values of 2. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (172,1,'Computers make very fast, very accurate mistakes. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (173,1,'Computers are not intelligent. They only think they are. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (174,1,'Why doesn\\\'t DOS ever say \"EXCELLENT command or filename!\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (175,1,'As a computer, I find your faith in technology amusing. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (176,1,'Southern DOS: Y\\\'all reckon? (Yep/Nope) \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (177,1,'Backups? We don\\\' *NEED* no steenking backups. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (178,1,'An error? Impossible! My modem is error correcting. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (179,1,'Who\\\'s General Failure & why\\\'s he reading my disk? \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (180,1,'ASCII stupid question, get a stupid ANSI! \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (181,1,'Error: Keyboard not attached. Press F1 to continue. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (182,1,'Press any key to continue or any other key to quit... \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (183,1,'Daddy, why doesn\\\'t this magnet pick up this floppy disk? \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (184,1,'l8nite is my daddy!  -slyfx\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (185,1,'Artificial intelligence usually beats real stupidity. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (186,1,'What does this mean \\\'mailer daemon\\\'? Satan, are you messing with the e-mail system already?    Herb Stern \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (187,1,'Where do I want to go today? Poland, Czechoslovakia, France. Can Microsoft Office do that for me?   Adolf Hitler \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (188,1,'Get thee behind me, Bill Gates. (aka Satan)\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (189,1,'One good reason why computers can do more work than people is that they never have to stop and answer the phone. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (190,1,'Back up my hard drive? How do I put it in reverse? \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (191,1,'Fast. Powerful. User-friendly. Now choose any two.    Eric Daniels \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (192,1,'A friend will help you solve your problems. A good friend will help you solve your computer problems.  Jason Q. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (193,1,'What\\\'s the difference between IBM and Jurassic Park?   One is a theme park full of ancient mechanical monsters that scare its customers; the other is a movie. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (194,1,'Windows 95: n. 32 bit extensions and a graphical shell for a 16 bit patch to an 8 bit operating system originally coded for a 4 bit microprocessor, written by a 2 bit company that can\\\'t stand 1 bit of competition. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (195,1,'The \\\'Internet\\\' cannot be removed from your desktop, would you like to delete the \\\'Internet\\\' now?   MS Windows 95 \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (196,1,'It\\\'s not the size of the hard drive that counts, it\\\'s how you download it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (197,1,'When downloading a large and important file from the internet, staring at the \\\'downloading\\\' light on your modem will cause the transfer to hang. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (198,1,'On the keyboard of life, always keep one finger on the escape key. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (199,1,'(A)bort, (R)etry, (G)et a beer? \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (200,1,'All computers wait at the same speed. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (201,1,'On the other hand, you have different fingers. - Erm\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (202,1,'Politically-Correct Virus: Never identifies itself as a \"virus,\" but instead refers to itself as an \"electronic micro-organism.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (203,1,'Paul Revere Virus: This revolutionary virus does not horse around. It warns you of impending hard disk attack: Once, if by LAN; twice if by C. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (204,1,'Dan Quayle Virus: Their is sumthing rong with your komputer, but ewe cant figyour outt watt! \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (205,1,'Plug-and-Play: a new hire who doesn\\\'t need any training. \"The new guy, John, is great. He\\\'s totally plug-and-play.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (206,1,'404: Someone who\\\'s clueless. From the World Wide Web message \"404, URL Not Found,\" meaning that the document you\\\'ve tried to access can\\\'t be located. \"Don\\\'t bother asking him... he\\\'s 404, man.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (207,1,'Cobweb Site: A World Wide Web Site that hasn\\\'t been updated for a long time. A dead web page. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (208,1,'Clues that you just might be a \\\'Net Junkie: When you start tilting your head sideways to smile, when you code your homework in HTML and give your instructor the URL, when you\\\'d rather go to http://www.weather.com/ than look out your window. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (209,1,'A computer is only as smart as the numbskull sitting in front of it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (210,1,'Redundant book title: \"Windows For Dummies\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (211,1,'Presumably, we\\\'re all fully qualified computer nerds here, so we are allowed to use \"access\" as a verb. Be advised, however, that the practice in common usage drives English-language purists to scowling fidgets. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (212,1,'I don\\\'t have anything against geeks. I was one for 11 years! I used to think PC\\\'s were the greatest thing since sliced bread... Then someone showed me sliced bread. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (213,1,'Think? Why think! We have computers to do that for us.   Jean Rostand \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (214,1,'How many Bill Gates does it take to change a light bulb?     None. He puts in the bulb and lets the world revolves round him.    None. He calls a meeting and makes darkness the standard.\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (215,1,'Video games, interestingly, are far better integrated and have much better performance than office software. I think this is because people who program video games love them, and care about the ideas, look and feel of the resulting product.')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (216,1,'There are many methods for predicting the future. For example, you can read horoscopes, tea leaves, tarot cards, or crystal balls. Collectively, these methods are known as \"nutty methods.\"')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (217,1,'Computers will never take the place of books. You can\\\'t stand on a floppy disk to reach a high shelf. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (218,1,'Hitting your modem with an aluminum baseball bat is only going to get you electrocuted. Try a wooden one. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (220,1,'One thing a computer can do that most humans can\\\'t is be sealed up in a cardboard box and sit in a warehouse.   Jack Handey , Deep Thoughts \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (221,1,'USER, n. The word computer professionals use when they mean \"idiot.\" \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (222,1,'Sometimes just a few hours of trial and error debugging can save minutes of reading manuals. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (223,1,'The nice thing about standards is that there are so many of them to choose from. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (224,1,'He who laughs last probably made a back up. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (225,1,'IBM means Idiots Behind Machines (I Blame Microsoft). \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (226,1,'We are Microsoft. Resistance is futile. You will be assimilated.  -seen on a t-shirt \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (227,1,'Technology is the knack of so arranging the world that we do not experience it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (228,1,'Hardware is the part of a computer that can be kicked, if all you can do is swear at it, then it must be software. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (229,1,'The application finished with the following error: The operation was completed succesfully.    Microsoft Exchange \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (230,1,'Pascal, n.: A programming language named after a man who would turn over in his grave if he knew about it. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (231,1,'Real programmers don\\\'t comment their code. It was hard to write, it should be hard to understand. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (232,1,'On a clear disk you can seek forever. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (233,1,'Meddle not in the affairs of cats, for they are subtle and will piss on your computer. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (234,1,'See, you not only have to be a good coder to create a system like Linux, you have to be a sneaky bastard too.   Linus Torvalds \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (235,1,'Always code as if the guy who ends up maintaining your code will be a violent psychopath who knows where you live.  Martin Golding \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (236,1,'A computer lets you make more mistakes faster than any invention in human history - with the possible exceptions of handguns and tequila.   Mitch Ratliffe \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (237,1,'The most galling thing about Windows is that it works best when it\\\'s not actually doing anything.\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (238,1,'Smith & Wesson... the original Point-N-Click interface. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (239,1,'Computers don\\\'t make mistakes... What they do they do on purpose! \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (240,1,'Ethernet (n): something used to catch the etherbunny. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (241,1,'RAM disk is NOT an installation procedure. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (242,1,'There are two major products that come out of Berkeley: LSD and UNIX. We don\\\'t believe this to be a coincidence. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (243,1,'If brute force doesn\\\'t solve your problem, you\\\'re just not using enough. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (244,1,'Speed Kills, Use Windows. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (245,1,'The most sophisticated piece of any technology is the chip that makes it break down the instant the warranty runs out. \n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (246,1,'Save the whales. Collect the whole set. - Erm\n')~ );
		$sql->ocQuery( qq~INSERT INTO quotes VALUES (247,1,'A day without sunshine is like night. - Erm\n')~ );
	}

	$sql->disconnectDB();

	print "------------------------------------\n";
	print "  Now the fun stuff - Bot config!!  \n";
	print "------------------------------------\n";

	exec( "perl addbot.pl" );

}

