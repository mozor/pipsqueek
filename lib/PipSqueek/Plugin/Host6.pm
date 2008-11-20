package PipSqueek::Plugin::Host6;
use base qw(PipSqueek::Plugin);

use Net::DNS;



sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'multi_host6',
    ]);
}


sub multi_host6
{
    my ($self,$message) = @_;
    my $input = $message->command_input();

    $input =~ s/\s+$//;
                
                my $res = Net::DNS::Resolver->new;
                my $answer = $res->send("$input", 'AAAA');
          if ($answer) {
                        foreach my $rr ($answer->answer) {
                        next unless $rr->type eq "AAAA";
                        my $address= $rr->address;
                        return $self->respond( $message, "$input has address of $address" );                        
                        }
        } else {
                        return $self->respond( $message, "Sorry, there are no IPv6 address(es) at $input." );
        }
}


1;


__END__
