package PipSqueek::Plugins::Stats;
use base qw(PipSqueek::Plugin);
use strict;

my %CATEGORIES = 
	map{ ($_,1) } qw( 
		chars words lines cpl wpl actions 
		smiles modes topics kicked kicks 
	);


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
	]);

	$self->plugin_handlers( 'multi_score' => 'multi_rank' );
}

sub plugin_teardown { }

# stats tracking
sub irc_ctcp_action
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);

	$self->_do_stats( $user, $message->message() );

	$user->{'stats'}->{'actions'}++;
}

sub irc_public
{
	my ($self,$message) = @_;
	return if $self->is_command($message);
	my $user = $self->find_user($message);

	$self->_do_stats( $user, $message->message() );
}

sub irc_topic
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);

	$user->{'stats'}->{'topics'}++;
}

sub irc_mode
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);

	$user->{'stats'}->{'modes'}++;
}

sub irc_kick
{
	my ($self,$message) = @_;

	my $user = $self->find_user($message);
	$user->{'stats'}->{'kicks'}++;

	$user = $self->find_user($message->recipients());
	$user->{'stats'}->{'kicked'}++;
}

sub _do_stats
{
	my ($self,$user,$text) = @_;
	my $stats = $user->{'stats'} ||= {};

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
	my ($username) = $message->message() =~ m/stats\s+(.+?)$/;

	if( my $user = $self->find_user( $username || $message ) )
	{
		unless( exists $user->{'stats'} )
		{
			return $self->respond( $message, 
				"No stats for that user yet" );
		}

		if( $user->{'cloaking'} && $username &&
			lc($username) ne lc($user->{'username'}) &&
			lc($username) ne lc($user->{'nickname'})
		)
		{
			return $self->respond( $message,
				"That user is cloaked, sorry!" );
		}

		my $stats = $user->{'stats'};
		my $output = "$user->{'username'}: ? chars, ? words, ".
		"? lines, ? cpl, ? wpl, ? actions, ? smiles, kicked ? lusers, ".
		"been kicked ? times, set ? modes, changed the topic ? times.";

		my @values = (
			$stats->{'chars'}, 
			$stats->{'words'},
			$stats->{'lines'},
			$stats->{'cpl'},
			$stats->{'wpl'},
			$stats->{'actions'},
			$stats->{'smiles'},
			$stats->{'kicks'},
			$stats->{'kicked'},
			$stats->{'modes'},
			$stats->{'topics'},
		);

		foreach my $value ( @values )
		{
			$value ||= 0;
			$value = sprintf("%.2f",$value);
			$value =~ s/\.00$//;
			$output =~ s/\?/$value/;

		}

		return $self->respond( $message, $output );
	}
	else
	{
		return $self->respond( $message, "That user does not exist" );
	}
}


sub multi_top10
{
	my ($self,$message) = @_;
	my ($category) = $message->message() =~ m/top10\s+'?(.+?)'?$/;
	    $category ||= 'chars';

	unless( exists $CATEGORIES{$category} )
	{
		return $self->respond( $message, "Unknown category" );
	}

	my @list = $self->_get_list( $category );
	my $udb  = $self->userdb();

	my @top10;
	foreach ( @list )
	{
		last if push(@top10, $_) == 10;
	}

	@top10 = map {
		my $user = $udb->{$_};
		my $username = $user->{'username'};
		my $str = sprintf("%s (%.2f)", 
				$username, 
				$user->{'stats'}->{$category}
			  );
		$str =~ s/\.00\b//g;
		$_ = $str;
	} @top10;

	local $" = ', ';
	return $self->respond( $message, "Top10 ('$category'): @top10!" );
}


sub multi_rank
{
	my ($self,$message) = @_;
	my $text = $message->message();
	   $text =~ s/\s+$//g;

	my ($command,@parts) = split(/\s+/,$text);
	my ($category, $input);

	if( @parts >= 2 )
	{
		$input = $parts[0];
		$category = $parts[1] || 'chars';
		$category =~ s/^'(.*?)'$/$1/;
	}
	elsif( @parts == 1 )
	{
		if( $parts[0] =~ m/^'(.*?)'$/ )
		{
			$category = $1;
			$input = $message->nick();
		}
		else
		{
			$category = 'chars';
			$input = $parts[0];
		}
	}
	else
	{
		$category = 'chars';
		$input = $message->nick();
	}

	unless( exists $CATEGORIES{$category} )
	{
		return $self->respond( $message, "Unknown category" );
	}

	my @list = $self->_get_list($category);
	my $udb  = $self->userdb();

	my ($found_user,$found_rank) = (undef,1);

	if( $input =~ /[^0-9]/ )
	{
		my ($user,$uid) = $self->find_user($input);
		if( defined($user) )
		{
			foreach ( @list )
			{
				last if $_ eq $uid;
				$found_rank++;
			}

			$found_user = $user;
		}
	}
	else
	{
		$found_user = $udb->{ $list[$input-1] };
		$found_rank = $input;
	}

	if( defined($found_user) && $found_rank != @list )
	{
		if( $found_user->{'cloaking'} && 
			$input && lc($input) ne lc($found_user->{'username'})
			&& lc($input) ne lc($found_user->{'nickname'})
		)
		{
			return $self->respond( $message,
				"That user is cloaked, sorry!" );
		}

		my $username = $found_user->{'username'};
		my $score = sprintf("%.2f",
				$found_user->{'stats'}->{$category}
			    );
		   $score =~ s/\.00\b//;

		return $self->respond( $message,
			"Rank $found_rank: $username ($score $category)" 
		);
	}
	else
	{
		return $self->respond( $message, "That user does not exist" );
	}
}

sub _get_list
{
	my ($self,$category) = @_;
	my $udb = $self->userdb();
	my @list =
		reverse 
		sort {
			$udb->{$a}->{'stats'}->{$category}
			<=>
			$udb->{$b}->{'stats'}->{$category}
		} keys %$udb;
	
	my @new;
	foreach my $user (@list)
	{
		next if $user eq "";
		next if $udb->{$user}->{'cloaking'};
		push(@new,$user);
	}

	return @new;
}


1;


