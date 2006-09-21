package PipSqueek::Plugin::Slap;
use base qw(PipSqueek::Plugin);


sub config_initialize
{
	my $self = shift;

	$self->plugin_configuration({
		'slap_verbs' =>
		'slaps,hits,smashes,beats,bashes,smacks,blats,punches,stabs,whacks',

		'slap_areas' => 
		'around the head,viciously,repeatedly,in the face,to death,savagely',

		'slap_sizes' => 
		'large,huge,small,tiny,miniscule,enormous,gargantuan,normal',

		'slap_tools' => 
		'trout,fork,mouse,bear,piano,cello,vacuum,mosquito,sewing needle,desk lamp',
	});
}


sub plugin_initialize 
{
	my $self = shift;
	my $c = $self->config();
	
	$self->plugin_handlers([
		'multi_slap'
	]);

	$self->{'verbs'} = [];
	$self->{'areas'} = [undef];
	$self->{'sizes'} = [undef];
	$self->{'tools'} = [];

	push(@{$self->{'verbs'}},$_) foreach split(/,/,$c->slap_verbs());
	push(@{$self->{'areas'}},$_) foreach split(/,/,$c->slap_areas());
	push(@{$self->{'sizes'}},$_) foreach split(/,/,$c->slap_sizes());
	push(@{$self->{'tools'}},$_) foreach split(/,/,$c->slap_tools());
}


sub multi_slap
{
	my ($self,$message) = @_;
	my $thing = $message->command_input() || $message->nick();
  $thing =~ s/\s{2,}/ /gi;
  $thing =~ s/\s*$//;

	my @verbs = @{$self->{'verbs'}};
	my @areas = @{$self->{'areas'}};
	my @sizes = @{$self->{'sizes'}};
	my @tools = @{$self->{'tools'}};

	my $verb = @verbs[rand @verbs];
	my $area = @areas[rand @areas];
	my $size = @sizes[rand @sizes];
	my $tool = @tools[rand @tools];

	return $self->respond_act( $message, 
		"$verb $thing " . ( $area ? "$area " : '' ) .
		'with a ' . ( $size ? "$size " : '') . "$tool" );
}


1;


__END__
