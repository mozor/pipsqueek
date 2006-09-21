package PipSqueek::Plugin::RSSGrabber;
use base qw(PipSqueek::Plugin);
use strict;

use LWP::UserAgent;
use XML::RSS;


sub config_initialize
{
	my $self = shift;

	$self->plugin_configuration(
		'rss_allow_custom_feeds' => 1,
		'rss_allow_respond_in_channel' => 0,
		'rss_max_num_stories' => 20,
		'rss_default_num_stories' => 4,
		'rss_http_timeout' => 6,
	);
}

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers(
		'multi_rss'	   => 'get_rss',
		'multi_rss_feeds' => 'show_feeds',
		'multi_+rss'	 => 'add_feed',
		'multi_-rss'	 => 'del_feed',
	);

	my $schema = [
		[ 'tag', 'VARCHAR PRIMARY KEY' ],
		[ 'url', 'VARCHAR' ],
	];
	$self->dbi()->install_schema('rss', $schema);
}

sub get_rss
{
	my ($self, $message) = @_;
	my $config = $self->config();

	my $print = sub {
		my $msg = shift;
		if ($config->rss_allow_respond_in_channel()) {
			$self->respond($message, $msg);
		} else {
			$self->client()->privmsg($message->nick(), $msg);
		}
		return;
	};

	my $args = $message->command_input();
	return unless $args;

	my @args = split /\s+/, $args;
	return unless scalar @args;

	my $url;
	my $arg1 = shift @args;

	if ($arg1 eq 'feeds') {
		return show_feeds(@_);
	}

	if ($arg1 =~ m#^http://#i && ! $config->rss_allow_custom_feeds()) {
		my $msg = 'Custom feeds are turned off. ';
		$msg .= 'Use "!rss feeds" for a list of feeds.';
		return $print->($msg);
	}
	if ($arg1 =~ m#^http://#i) {
		$url = $arg1;
	} else {
		$url = $self->url_from_tag($arg1);
		unless (defined $url) {
			my $msg = "Could not find feed.  ";
			$msg .= 'Use "!rss feeds" for a list of feeds.';
			return $print->($msg);
		}
	}

	my $num_stories = $config->rss_default_num_stories();
	if (scalar @args) {
		my $num = shift @args;
		if ($num < $config->rss_max_num_stories()) {
			$num_stories = $num;
		} else {
			$num_stories = $config->rss_max_num_stories();
		}
	}

	my $rss = $self->rss_from_url($url);
	return $print->($rss) unless UNIVERSAL::isa($rss, 'XML::RSS');

	my @items = @{ $rss->{items} };
	return $print->('Did not get any news items.') unless scalar @items;
	if (scalar @items > $num_stories) {
		splice @items, $num_stories;
	}
	$print->(scalar @items . " most recent stories:");
	for my $story (@items) {
		$print->($self->unescape($story->{title}) . ' - ' . $story->{'link'});
	}

	return;
}

sub show_feeds
{
	my ($self, $message) = @_;
	my $config = $self->config();
	my $dbh = $self->dbi()->dbh();
	my $sth = $dbh->prepare("SELECT tag FROM rss");
	my @tags = ();
	$sth->execute() or return;
	while (my $row = $sth->fetchrow_arrayref) {
		push @tags, $row->[0];
	}
	my $msg = 'Available feeds: ';
	$msg .= join ', ', @tags;
	if ($config->rss_allow_respond_in_channel()) {
		$self->respond($message, $msg);
	} else {
		$self->client()->privmsg($message->nick(), $msg);
	}
}

sub add_feed
{
	my ($self, $message) = @_;
	my ($tag, $url) = split /\s+/, $message->command_input();
	unless (defined $tag && defined $url) {
		my $msg = "Usage: !+rss tag URL";
		$self->respond($message, $msg);
		return;
	}
	my $rss = $self->rss_from_url($url);
	unless (UNIVERSAL::isa($rss, 'XML::RSS')) {
		my $msg = "Invalid feed: $rss";
		$self->respond($message, $msg);
		return;
	}
	my $dbh = $self->dbi()->dbh();
	my $sth = $dbh->prepare("SELECT * FROM rss WHERE tag=?");
	my $rv = $sth->execute($tag);
	my $row = $sth->fetchrow_arrayref();
	$sth->finish();
	if ($row) {
		my $msg = "A feed already exists with the tag '$tag'";
		$self->respond($message, $msg);
		return;
	}
	$sth = $dbh->prepare("INSERT INTO rss (tag, url) VALUES (?, ?)");
	$rv = $sth->execute($tag, $url);
	unless ($rv) {
		my $msg = "DBI error: " . $dbh->errstr();
		$self->respond($message, $msg);
		return;
	}
	$self->respond($message, "RSS feed added");
}

sub del_feed
{
	my ($self, $message) = @_;
	my ($tag) = split /\s+/, $message->command_input();
	unless (defined $tag) {
		my $msg = "Usage: !-rss tag";
		$self->respond($message, $msg);
		return;
	}
	my $dbh = $self->dbi()->dbh();
	my $rv = $dbh->do("DELETE FROM rss WHERE tag = ?", undef, $tag);
	my $msg;
	if ($rv) {
		$msg = "Feed deleted";
	} else {
		$msg = "No feeds deleted";
	}
	$self->respond($message, $msg);
}

# Returns an XML::RSS object or a string error message
sub rss_from_url
{
	my $self = shift;
	my $url = shift;

	my $agent = LWP::UserAgent->new('agent' => 'Mozilla/5.0');
	$agent->timeout($self->config()->rss_http_timeout());
	my $response = $agent->get($url); 
	unless ($response->is_success()) {
		my $msg = "HTTP Error for $url: " . $response->status_line();
		return $msg;
	}

	my $rss = XML::RSS->new();
	eval {
		$rss->parse($response->content());
	};
	if ($@) {
		my $msg = "Error parsing RSS.  It's probably invalid: $@";
		return $msg;
	} else {
		return $rss;
	}
}

sub url_from_tag
{
	my $self = shift;
	my $tag = shift;
	my $dbh = $self->dbi()->dbh();
	my $sth = $dbh->prepare("SELECT url FROM rss WHERE lower(tag) = ?");
	$sth->execute(lc($tag)) or return undef;
	my @row = $sth->fetchrow_array();
	return $row[0];
}

sub unescape
{
	my $self = shift;
	my $what = shift;
	$what =~ s/&lt;/</g;
	$what =~ s/&gt;/</g;
	$what =~ s/&quot;/"/g;
	$what =~ s/&apos;/'/g;
	$what =~ s/&amp;/&/g;
	return $what;
}

1;
__END__
