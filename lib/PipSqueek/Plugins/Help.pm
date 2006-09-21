package PipSqueek::Plugins::Help;
use base qw(PipSqueek::Plugin);

use File::Find;
use File::Spec::Functions;

my $HELP;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_help',
	]);

	# load help from plugin files
	find({ 'wanted' => sub
	{
		s/.*\///;
		my $handler = $_;

		open( my $fh, '<', $File::Find::name ) 
			or return warn "Error loading '$File::Find::name': $!";
			my @help = map { 
				chomp; 
				if( defined($_) && $_ ne "" ) { $_; }
			} <$fh>;
			close( $fh );

			$HELP->{$handler}->{'usage'} = shift @help;
			$HELP->{$handler}->{'help'}  = join(' ', @help);

		}, 'no_chdir' => 1, },

		catdir( $self->cwd(),  'doc/plugins'    ),
		catdir( $FindBin::Bin, '../doc/plugins' ),
	);
}

sub plugin_teardown { }

sub multi_help
{
	my ($self,$message) = @_;
	my $prefix = $self->config()->param('public_command_prefix');
	my ($event) = $message->message() =~ m/help\s+(?:$prefix)?(.+)$/;

	if( defined($event) && (
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

		$self->privmsg( $message->nick(), 
			"Help on $scope command '$event'");
		$self->privmsg( $message->nick(), 
			"Usage: $help->{'usage'}" );
		$self->privmsg( $message->nick(), 
			"Description: $help->{'help'}" );

		return;
	}
	else
	{
		if( defined($event) )
		{
			return $self->privmsg( $message->nick(),
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
			$self->privmsg( $message->nick(), 
				"Multi Commands: @multi" ) if @multi;
			$self->privmsg( $message->nick(), 
				"Public Commands: @public" ) if @public;
			$self->privmsg( $message->nick(), 
				"Private Commands: @private" ) if @private;

			return;
		}
	}
}


1;


