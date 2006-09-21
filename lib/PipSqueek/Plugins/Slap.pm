package PipSqueek::Plugins::Slap;
use base qw(PipSqueek::Plugin);


my @verbs = (
	'slaps', 'hits', 'smashes', 'beats',
	'bashes', 'smacks', 'blats', 'punches' );

my @areas = ( 
	'around the head', 'viciously', 'repeatedly', 
	'in the face', 'to death', undef );

my @sizes = ( 'large', 'huge', 'small', 'tiny', undef );

my @tools = qw( trout fork mouse bear piano chello vacuum mosquito );


sub plugin_initialize {
	(shift)->plugin_handlers(['multi_slap']);
}

sub plugin_teardown { }

sub multi_slap
{
	my ($self,$message) = @_;
	my ($thing) = $message->message() =~ m/slap\s+(.+)$/;
	
	my $verb = @verbs[rand @verbs];
	my $area = @areas[rand @areas];
	my $size = @sizes[rand @sizes];
	my $tool = @tools[rand @tools];

	if( !defined($thing) || $thing eq "" || lc($thing) eq lc($self->nickname()) )
	{
		$thing = $message->nick();
	}

	return $self->respond_act( $message, 
		"$verb $thing " . ( $area ? "$area " : '' ) .
		'with a ' . ( $size ? "$size " : '') . "$tool" );
}


1;


