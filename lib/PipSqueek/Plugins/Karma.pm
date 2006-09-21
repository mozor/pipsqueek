package PipSqueek::Plugins::Karma;
use base qw(PipSqueek::Plugin);

use File::Spec::Functions;

my $KARMA;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'irc_public',
		'multi_karma',
	]);

	$self->karma_load_data();
}

sub plugin_teardown 
{
	my $self = shift;
	$self->karma_save_data();
}



sub irc_public
{
	my ($self,$message) = @_;

	$self->grok_karma( $message->message() );
}


sub grok_karma
{
	my ($self,$line) = @_;
	my $flag = 0;

	while( $line =~ s/\(?(.+?)\)?(?:(\+\+|\-\-))+// )
	{
		my ($atom,$mod) = ($1,$2);
		    $flag = 1;

		my $obj = $KARMA->{lc($atom)} ||= 
			  { 'value' => $atom, 'karma' => 0 };

		$obj->{'karma'}++ if $mod eq '++';
		$obj->{'karma'}-- if $mod eq '--';
	}

	return $flag;
}


sub multi_karma
{
	my ($self,$message) = @_;
	my ($atom) = $message->message() =~ m/karma\s+(.+)$/;

	if( $atom )
	{
		if( my $obj = $KARMA->{lc($atom)} )
		{
			return $self->respond( $message, 
				"$obj->{'value'} has $obj->{'karma'} karma" );
		}
		else
		{
			return $self->respond($message, "$atom has no karma");
		}
	}
	else
	{
		if( keys %$KARMA )
		{
			my @highest = reverse sort { 
				$KARMA->{$a}->{'karma'}
				<=> 
				$KARMA->{$b}->{'karma'} } keys %$KARMA;

			my @lowest  = sort { 
				$KARMA->{$a}->{'karma'}
				<=>
				$KARMA->{$b}->{'karma'} } keys %$KARMA;

			my @highout;
			my @lowout;

			foreach my $key (@highest)
			{
				push(@highout, $KARMA->{$key});
				last if @highout == 3;
			}

			foreach my $key (@lowest)
			{
				push(@lowout, $KARMA->{$key});
				last if @lowout == 3;
			}

			my @h = map {
				"'$_->{'value'}' ($_->{'karma'})" 
			} @highout;
			
			my @l = map {
				"'$_->{'value'}' ($_->{'karma'})"
			} @lowout;

			local $" = ', ';
			$self->respond( $message, "Highest Karma: @h" );
			$self->respond( $message, " Lowest Karma: @l" );
		}
		else
		{
			return $self->respond( $message, "There is no karma" );
		}
	}
}



####
# data load/save routines
sub karma_load_data
{
	my $self = shift;
	my $file = catfile( $self->cwd(), '/var/karma.dat' );

	if( -e $file )
	{
		open( my $fh, '<', $file ) 
			or return warn "Error opening '$file': $!";
		my @lines = <$fh>;
		chomp(@lines);
		close( $fh );

		foreach (@lines)
		{
			my ($k,$v,$l) = split(/\t/,$_);
			$KARMA->{$k} = { 'karma' => $v, 'value' => $l };
		}
	}
}

sub karma_save_data
{
	my $self = shift;
	my $file = catfile( $self->cwd(), '/var/karma.dat' );

	if( keys %$KARMA )
	{
		open( my $fh, '>', $file ) 
			or return warn "Error writing '$file': $!";

		while( my ($k,$v) = each %$KARMA )
		{
			print $fh "$k\t$v->{'karma'}\t$v->{'value'}\n";
		}

		close( $fh );
	}
}


1;


