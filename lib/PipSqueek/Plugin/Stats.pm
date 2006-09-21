package PipSqueek::Plugin::Stats;
use base qw(PipSqueek::Plugin);
use strict;

use LWP::UserAgent; # For fah_top10.

sub config_initialize
{
	my $self = shift;
	
	$self->plugin_configuration({
		'fah_team_stats_url'	=> 'http://vspx27.stanford.edu/cgi-bin/main.py?qtype=teampage&teamnum=38753',
		'fah_http_timeout'	=> 30,
	});
}

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		# we track these ones to get the stats for them
		'irc_ctcp_action',
		'irc_public',
		'irc_topic',
		'irc_kick',
		'irc_mode',

		# these are our public interface
		'multi_stats',
		'multi_top10',
		'multi_rank',

		# when a user merges we need to merge their stats
		'pipsqueek_mergeuser',
	]);

	$self->plugin_handlers( 'multi_score' => 'multi_rank' );


	# set up our database table
	my $schema = [
		[ 'id', 	'INTEGER PRIMARY KEY' ],
		[ 'userid',	'INT NOT NULL' ],
	];

	my %CATEGORIES = 
	map{ ($_,1) } qw( 
		chars words lines cpl wpl actions 
		smiles modes topics kicked kicks
	);


	foreach my $cat ( keys %CATEGORIES )
	{
		push(@$schema, [ $cat, 'FLOAT' ]);
	}

	$self->{'CATEGORIES'} = \%CATEGORIES;

	$self->dbi()->install_schema( 'stats', $schema );
}


# some helper functions for the database
sub search_stats
{
	my ($self,$message) = @_;
	my $user = $self->search_or_create_user($message);

	my $stats = $self->dbi()->select_record( 'stats',
			{ 'userid' => $user->{'id'} } 
		    );

	unless( $stats )
	{
		$stats = 
		$self->dbi()->create_record( 'stats',
			{ 'userid' => $user->{'id'} }
		);
	}

	return $stats;
}


sub save_stats
{
	my ($self,$stats) = @_;
	$self->dbi()->update_record( 'stats', $stats );
}


# stats tracking
sub irc_ctcp_action
{
	my ($self,$message) = @_;

	my $stats = $self->search_stats($message);
	   $stats->{'actions'}++;

	$self->_do_stats( $stats, $message->message() );

	$self->save_stats( $stats );
}


sub irc_public
{
	my ($self,$message) = @_;
	return if $message->is_command();

	my $stats = $self->search_stats($message);

	$self->_do_stats( $stats, $message->message() );

	$self->save_stats( $stats );
}


sub irc_topic
{
	my ($self,$message) = @_;
	my $stats = $self->search_stats($message);

	$stats->{'topics'}++;

	$self->save_stats( $stats );
}


sub irc_mode
{
	my ($self,$message) = @_;
	my $stats = $self->search_stats($message);

	$stats->{'modes'}++;

	$self->save_stats( $stats );
}


sub irc_kick
{
	my ($self,$message) = @_;
	my $from_stats = $self->search_stats($message);
	my $to_stats   = $self->search_stats($message->recipients());

	$from_stats->{'kicks'}++;
	$to_stats->{'kicked'}++;

	$self->save_stats( $from_stats );
	$self->save_stats( $to_stats );
}


sub _do_stats
{
	my ($self,$stats,$text) = @_;

	my @chars = split(//,$text);
	my @words = split(/\s+/,$text);

	unless( @words == 1 && $words[0] =~ /^\s*\*|\*\s*$/ )
	{
		$stats->{'chars'} += @chars;
		$stats->{'words'} += @words;
		$stats->{'lines'} += 1;
	}

	$stats->{'cpl'} = $stats->{'chars'} / $stats->{'lines'};
	$stats->{'wpl'} = $stats->{'words'} / $stats->{'lines'};

	# always run this last, it clobbers $text
	while ( $text =~ s/[\%=:;8B][o^~-]?[|\/\\{}\[\]()<>XxFfPpOoDdCc]// )
	{
		$stats->{'smiles'}++;
	}

	while( $text =~ s/[°oO0-^][_-][°oO0-^]// )
	{
		$stats->{'smiles'}++;
	}
}


# Public Interface
sub multi_stats
{
	my ($self,$message) = @_;
	my $username = $message->command_input();
       $username =~ s/^\s*|\s*$//g;

	$username =~ s/\s+$//;

	my $user  = $self->search_user( $username || $message );

	unless( $user )
	{
		$self->respond( $message, "That user doesn't exist, sorry." );
		return;
	}
	

	my $stats = $self->search_stats( $username || $message );

	my $output = "$user->{'username'}: ? chars, ? words, ".
	"? lines, ? cpl, ? wpl, ? actions, ? smiles, kicked ? lusers, ".
	"been kicked ? times, set ? modes, changed the topic ? times.";

	my @values = map { $stats->{$_} } 
	qw(chars words lines cpl wpl actions smiles kicks kicked modes topics);

	foreach my $value ( @values )
	{
		$value ||= 0;
		$value = sprintf("%.2f",$value);
		$value =~ s/\.00$//;
		$output =~ s/\?/$value/;
	}

	$self->respond( $message, $output );
	return;
}


sub multi_top10
{
	my ($self,$message) = @_;
	my $category = $message->command_input() || 'chars';

	if( $category eq 'fah' )
	{
		$self->fah_top10($message);
		return;
	}
	
	if( $category =~ /^quotes?$/ )
	{
		my $mode = $message->event() =~ /^private_/ ? 'private' : 'public';
		my $event = $mode . "_top10quotes";
		$self->client()->yield( $event, @{$message->raw()} );
		return;
	}
	
	unless( exists $self->{'CATEGORIES'}->{$category} )
	{
		$self->respond( $message, "Unknown category" );
		return;
	}

	my $dbh = $self->dbi()->dbh();
	my $sth = $dbh->prepare( 
		"SELECT * FROM stats ORDER BY $category DESC LIMIT 10"
		  );
	   $sth->execute();

	my @top10;

	while( my $row = $sth->fetchrow_hashref('NAME_lc') )
	{
		my $user = $self->select_user( { 'id' => $row->{'userid'} } );
		my $name = $user->{'username'};

		my $str = sprintf("%s (%.2f)", $name, $row->{$category});
		   $str =~ s/\.00\b//g;

		push(@top10, $str);
	}

	local $" = ', ';
	$self->respond( $message, "Top10 ('$category'): @top10!" );
	return;
}


# !rank [username | position] [category]
sub multi_rank
{
	my ($self,$message) = @_;
	my $input = $message->command_input();

	my ($name_or_rank, $category) = split( /\s+/, $input );
	$category ||= 'chars';

	unless( exists $self->{'CATEGORIES'}->{$category} )
	{
		return $self->respond( $message, "Unknown category" );
	}

	my $username = undef;
	my $ranking  = undef;

	$name_or_rank ||= $message->nick();

	# find the ranking of a person by their name
	if( $name_or_rank =~ /[^\d]/ )
	{
		my $user = $self->search_user( $name_or_rank );

		unless( $user )
		{
			$self->respond( $message, "User not found." );
			return;
		}
		
		my $sql = "SELECT userid FROM stats s ORDER BY $category DESC";
		my $sth = $self->dbi()->dbh()->prepare( $sql );
		   $sth->execute();

		$ranking = 0;
		while( my $row = $sth->fetchrow_hashref('NAME_lc') )
		{
			$ranking++;
			last if( $user->{'id'} == $row->{'userid'} )
		}

		$username  = $user->{'username'};
	}
	# find the name of a person by their rank
	else
	{
		my $sql = "SELECT u.username FROM stats s,users u " .
			  "WHERE s.userid=u.id ORDER BY $category DESC";
		my $sth = $self->dbi()->dbh()->prepare( $sql );
		   $sth->execute();

		$ranking = 0;
		while( my $row = $sth->fetchrow_hashref('NAME_lc') )
		{
			if( ++$ranking == $name_or_rank )
			{
				$username = $row->{'username'};
				last;
			}
		}

		unless( $username )
		{
			$self->respond( $message, "Rank not found." );
			return;
		}
	}

	my $stats = $self->search_stats( $username );
	my $score = sprintf("%.2f", $stats->{$category});
	   $score =~ s/\.00\b//;

	$self->respond( $message,
			"Rank $ranking: $username ($score $category)" );

	return;
}


# merge user2 into user1 and delete user2's information
sub pipsqueek_mergeuser
{
	my ($self,$message,$user1,$user2) = @_;

	my $stats1  = $self->search_stats( $user1 );
	my $stats2  = $self->search_stats( $user2 );

	foreach my $category ( keys %{$self->{'CATEGORIES'}} )
	{
		$stats1->{$category} += $stats2->{$category};
	}
	
	$stats1->{'cpl'} = $stats1->{'chars'} / $stats1->{'lines'};
	$stats1->{'wpl'} = $stats1->{'words'} / $stats1->{'lines'};

	$self->save_stats( $stats1 );

	$self->dbi()->delete_record( 'stats', $stats2 );
}

# Respond with the top 10 list of fah participants.
sub fah_top10
{
	my ($self,$message) = @_;
	
	my $config = $self->config();
	
	# Much of the following LWP::UserAgent business was taken from
	# RSSGrabber.pm since I'm currently rather hungry and feeling
	# rather lazy. That raises a question that I feel I should address:
	# Why am I programming when I'm hungry and lazy? That
	# can't be an entirely good idea.
	
	my $agent = LWP::UserAgent->new('agent' => 'Mozilla/5.0');
	
	# The following timeout was found in RSSGrabber.pm
	# Meh, this is all ready setup, so I might as well use it.
	# Perhaps this should be generalized to http_timeout()?
	$agent->timeout( $config->fah_http_timeout() );
	
	my $response = $agent->get( $config->fah_team_stats_url() );
	unless( $response->is_success() )
	{
		$self->respond( $message, "HTTP Error: " . $config->fah_team_stats_url() . ": " . $response->status_line() );
	}
	
	my $content = $response->content();
	
	my @top10;
	
	for my $i (1 .. 10) {
		# Is the following ugly? Perhaps. However, it does work.
		# Okay, here's the result:
		# $1 is the username,
		# $2 are the points for $1,
		# and $3 is the number of work units that $1 has completed.
		
		# Oh, and Shaun: I've been taking great care to follow your coding style. :-)
		# Not that I entirely agree with it, but it is your choice. ;-)
		if( $content =~ /teamnum=\d+&username=.*?">\s(.*?)\s.*?cert.*?target="_blank">\s(.*?)\s.*?cert.*?target="_blank">\s(.*?)\s/gis )
		{
			push(@top10, "$1 ($2)");
		}
	}
	
	# Shaun, the following trick is fantastic. I found it in your code above and it's really useful. :-)
	local $" = ', ';
	$self->respond( $message, "Top10 ('fah'): @top10!" );
	return;
}

1;


