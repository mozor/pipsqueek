package Handlers::Public::URLGen;
#
# This package handles generating a search URL for various websites
# atm: CPAN, google, perldoc
#
use base 'PipSqueek::Handler';
use strict;
use URI::URL;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_cpan'		=> \&public_cpan,
		'public_google' 	=> \&public_google,
		'public_perldoc'	=> \&public_perldoc,
		'public_freshmeat'	=> \&public_freshmeat,
		'public_sourceforge'	=> \&public_sourceforge,
		'public_javadoc'	=> \&public_javadoc,
		'public_search' 	=> \&public_google,
		'public_dictionary'	=> \&public_dictionary,
		'public_dict'		=> \&public_dictionary,
	};
}


sub get_description
{
	my $self = shift;
	my $type = shift;
	$type =~ s/public_//;
	foreach ($type) {
		return "Generate a search URL for $type";
	}
}

sub get_usage
{
	my $self = shift;
	my $type = shift;
	$type =~ s/public_//;
	return "!$type <search text>";
}


sub public_cpan
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $search = $event->param('msg');
	return unless $search;

	my $url = "http://search.cpan.org/search?mode=module&query=$search";
	$url = URI::URL->new($url);
	$bot->chanmsg( $url->as_string );
}


sub public_google
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $search = $event->param('msg');
	return unless $search;

	
	my $url = "http://www.google.com/search?q=$search";
	$url = URI::URL->new($url);
	$bot->chanmsg( $url->as_string );
}


sub public_perldoc
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $search = $event->param('msg');
	return unless $search;

	$search =~ s/^\s+//; $search =~ s/\s+$//;
	$search =~ s/^-f\s+//;

	my $url = "http://www.perldoc.com/cgi-bin/htsearch?words=$search&restrict=perl5.6.1";
	$url = URI::URL->new($url);
	$bot->chanmsg($url->as_string);
}

sub public_freshmeat
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;
	
	my $search = $event->param('msg');
	return unless $search;
	
	my $url = "http://freshmeat.net/search/?q=$search&section=projects";
	$url = URI::URL->new($url);
	$bot->chanmsg( $url->as_string );
}

sub public_sourceforge
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;
	
	my $search = $event->param('msg');
	return unless $search;
	
	my $url = "http://sourceforge.net/search/?type_of_search=soft&words=$search";
	$url = URI::URL->new($url);
	$bot->chanmsg( $url->as_string );
}

sub public_javadoc
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	
	my $searchType = 'and?';
		# 'and' for 'with all the words'
		# 'phr' for 'with the exact phrase'
		# 'qt'  for 'with any of the words'
		# 'not' for 'without the words'


	my $searchLoc = 'field='; #Where sun's java search engine searches
		# ''            for in 'Anywhere in page'
		# 'title'       for in 'title of page'
		# 'description' for in 'description of page'
		# 'keywords'    for in 'keywords of page'
		# 'url'		for in 'url of page'

	my $searchDate = 'since='; #create date of document...
		#""  Anytime
		#"604800"	In the last week
		#"1209600"	In the last 2 weeks
		#"2592000"	In the last month
		#"5184000"	In the last 2 months
		#"7776000"	In the last 3 months
		#"15552000"	In the last 6 months
		#"31536000"	In the last year
		#"63072000"	In the last 2 years


	my $searchBy = '0';
		#0 => Relevance
		#1 => Date

	my $searchDomain = 'col=javadoc'; #limitation to... combine those wanted
		#'col=java' 		=> java.sun.com
		#'col=javadoc' 		=> javadoc (APIs)
		#'col=javatutorials'	=> java tutorials
		#'col=javacodesamples'	=> java code sames
		#'col=javatecharticles'	=> java tech articles
		#'col=javabugs'		=> java bugs
		#'col=javaforums'	=> java forums
		#'col=industry'		=> industry
		#'col=solmarket'	=> Solutions market
		#'col=wireless'		=> wireless

	my $searchResults = 'nh=10'; #number of results per page...
		#10,25,50,100 are the options given per page... modify to non std at Sun's risk...

	
	my $search = $event->param('msg');
	return unless $search;
	$search = $searchType.$search.'&'.$searchLoc.'&'.$searchDate.'&'.$searchResults.'&'.$searchDomain;

	my $url = "http://search.java.sun.com/search/java/index.jsp?$search";
	$url = URI::URL->new($url);
	$bot->chanmsg( $url->as_string );
}

sub public_dictionary
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my $search = $event->param( 'msg' );
	return unless $search;

	my $url = "http://dictionary.reference.com/search?q=$search";
	$url = URI::URL->new($url);
	$bot->chanmsg( $url->as_string );
}


1;

