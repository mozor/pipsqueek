package PipSqueek::Plugin::SpudGun;
use base qw(PipSqueek::Plugin);

sub plugin_initialize {
    my $self = shift;

    $self->plugin_handlers( [ 'multi_spudgun' ] );
}

sub multi_spudgun {
    my ( $self, $message ) = @_;
    
    # Spud settings
    my @how   = qw( smashed shot bopped hit splattered slammed nailed creamed 
        bonked smacked clobbered mauled popped );
    my @where = qw( face hand thumb arm gut eye leg chin gut butt skull head 
        ass groin nads boob ear toe foot nose jimmy );
    my @what = ( "a potato", "a flying spud", "a high velocity spud",
      "a rocketing potato", "a deadly spud", "a potato of death",
      "the Mother of All Potatoes", "a hot potato", "a sweet potato", 
      "a vicious tater" );

    # Fire in the hole!!!
    my $victim  = $message->command_input;
    $victim =~ s/\s+$//;
    unless( $victim ) {
        $self->respond( $message, "You must specify a victim." );
        return;
    }

    my $spudgun = sprintf "$victim got %s in the %s by %s.",
        $how  [ rand @how   ],
        $where[ rand @where ],
        $what [ rand @what  ];

    $self->respond( $message, $spudgun );
}

1;

__END__
