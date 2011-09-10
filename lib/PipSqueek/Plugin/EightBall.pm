package PipSqueek::Plugin::EightBall;
use base qw(PipSqueek::Plugin);

sub plugin_initialize 
{
    my $self = shift;
    
    $self->plugin_handlers([
        'multi_8ball'
    ]);

    $self->{'yn'} = [
        "Ask Again Later",
        "Better Not Tell You Now",
        "Concentrate and Ask Again",
        "Don't Count on It",
        "It Is Certain",
        "Most Likely",
        "My Reply is No",
        "My Sources Say No",
        "No",
        "Outlook Good",
        "Outlook Not So Good",
        "Reply Hazy, Try Again",
        "Signs Point to Yes",
        "Yes",
        "Yes, Definitely",
        "You May Rely On It",
    ];
}


sub multi_8ball
{
    my ($self,$message) = @_;
    my $thing = $message->command_input();

	# srand doesn't appear to work with ActivePerl
	# srand time;
    $self->respond($message, @{$self->{'yn'}}[rand @{$self->{'yn'}}]);
}


1;


__END__
