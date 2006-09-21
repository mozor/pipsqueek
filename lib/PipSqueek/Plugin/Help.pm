package PipSqueek::Plugin::Help;
use base qw(PipSqueek::Plugin);

use File::Find;
use File::Spec::Functions qw(catdir);

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_help',
	]);

	my $client = $self->client();

	# load help from plugin files
	find({ 'wanted' => sub
	{
		s/.*\///;
		my $handler = $_;
		return unless -f $File::Find::name;

		open( my $fh, '<', $File::Find::name ) 
			or return warn "Error loading '$File::Find::name': $!";

		my @help = grep( /[^\s+]/, <$fh> );
		chomp(@help);
		close( $fh );

		$self->{'HELP'}->{$handler}->{'usage'} = shift @help;
		$self->{'HELP'}->{$handler}->{'help'}  = \@help;

	}, 'no_chdir' => 1, },

	catdir( $client->BASEPATH(), '/doc/plugins' ),
	catdir( $client->ROOTPATH(), '/doc/plugins' ),

	);
}


sub multi_help
{
	my ($self,$message) = @_;
	my $prefix = $self->config()->public_command_prefix();
	my $event  = join( '_', split(/\s+/,$message->command_input()) );

	my $HELP = $self->{'HELP'};

	if( defined($event) && $event ne "" && (
		   exists $HELP->{"public_$event"} 
		|| exists $HELP->{"private_$event"} 
		|| exists $HELP->{"multi_$event"} 
	) )
	{
		my $scope;
		my $help;

		if( exists $HELP->{"public_$event"} ) {
			$scope = "public"; $help = $HELP->{"public_$event"};
		}
		if( exists $HELP->{"private_$event"} ) {
			$scope = "private"; $help = $HELP->{"private_$event"};
		}
		if( exists $HELP->{"multi_$event"} ) {
			$scope = "multi"; $help = $HELP->{"multi_$event"};
		}

		$self->client()->privmsg( $message->nick(), 
			"Usage: $help->{'usage'}" );

		foreach my $line ( @{$help->{'help'}} )
		{
			$self->client()->privmsg( $message->nick(), "$line" );
		}

		return;
	}
	else
	{
		if( defined($event) && $event ne "" )
		{
			return $self->client()->privmsg( $message->nick(),
				"Unknown event '$event'" );
		}
		else
		{
			my @commands = sort keys %$HELP;

			my @multi   = map { s/^multi_//;  $_ } 
					grep( /^multi_/,   @commands );
			my @private = map { s/^private_//; $_ } 
					grep( /^private_/, @commands );
			my @public  = map { s/^public_//;  $_ } 
					grep( /^public_/,  @commands );

			local $"=', ';
			$self->client()->privmsg( $message->nick(), 
				"Multi Commands: @multi" ) if @multi;
			$self->client()->privmsg( $message->nick(), 
				"Public Commands: @public" ) if @public;
			$self->client()->privmsg( $message->nick(), 
				"Private Commands: @private" ) if @private;

			return;
		}
	}
}


1;


__END__
