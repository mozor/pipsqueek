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
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Generate a search URL for google" if( /public_google/ );
		return "Generate a search URL for cpan" if( /public_cpan/ );
		return "Generate a search URL for perldoc" if( /public_perldoc/ );
		}
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

1;

