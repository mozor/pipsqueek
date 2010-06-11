package PipSqueek::Plugin::Seppuku;
use base qw(PipSqueek::Plugin);


sub config_initialize
{
    my $self = shift;

    $self->plugin_configuration({
        'seppuku_verbs' =>
        'impales,runs through,thrusts,jabs,spikes,eviscerates,stakes,pierces,stabs',

        'seppuku_areas' =>
        'liver,heart,kidney,large intestine,lung',

        'seppuku_sizes' =>
        'rusty,dull,sharp,blunt,razor-sharp,edgeless,unsharpened,tiny',

        'seppuku_tools' =>
        'sword,knife,lancet,bayonet,shiv,ulu,wakizashi,dagger,sewing needle',
    });
}


sub plugin_initialize
{
    my $self = shift;
    my $c = $self->config();

    $self->plugin_handlers([
        'multi_seppuku'
    ]);

    $self->{'verbs'} = [];
    $self->{'areas'} = [undef];
    $self->{'sizes'} = [undef];
    $self->{'tools'} = [];

    push(@{$self->{'verbs'}},$_) foreach split(/,/,$c->seppuku_verbs());
    push(@{$self->{'areas'}},$_) foreach split(/,/,$c->seppuku_areas());
    push(@{$self->{'sizes'}},$_) foreach split(/,/,$c->seppuku_sizes());
    push(@{$self->{'tools'}},$_) foreach split(/,/,$c->seppuku_tools());
}


sub multi_seppuku
{
    my ($self,$message) = @_;
    my $thing = $message->command_input() || $message->nick();
    $thing =~ s/\s+$//;

    my @verbs = @{$self->{'verbs'}};
    my @areas = @{$self->{'areas'}};
    my @sizes = @{$self->{'sizes'}};
    my @tools = @{$self->{'tools'}};

    my $verb = @verbs[rand @verbs];
    my $area = @areas[rand @areas];
    my $size = @sizes[rand @sizes];
    my $tool = @tools[rand @tools];

    return $self->respond_act( $message,
        "$verb $thing" . ( $area ? "'s $area " : ' ' ) .
        'with a ' . ( $size ? "$size " : '') . "$tool" );
}


1;


__END__
