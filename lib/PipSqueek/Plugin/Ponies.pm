package PipSqueek::Plugin::Ponies;
use base qw(PipSqueek::Plugin);

sub plugin_initialize {
    my $self = shift;

    $self->plugin_handlers(
        'public_ponies++' => 'multi_ponies',
        'public_ponies--' => 'multi_ponies',

        'pipsqueek_mergeuser' => 'pipsqueek_mergeuser',
    );
}

sub multi_ponies {

    my ( $self, $message ) = @_;
    my $name   = $message->command_input();
    my $event  = $message->event();
    my $sender = $self->search_or_create_user( $message );

    if ( $name ) {
        $user = $self->search_user( $name );
        unless ( $user ) {
            $self->respond( $message, "That user does not exist" );
            return;
        }
    }

    if (   $name eq lc( $sender->{ 'username' } )
        || $name eq lc( $sender->{ 'nickname' } ) ) {
        $self->respond( $message, "You can't give yourself a pony!" );
        return;
    }

    my $stat = $self->dbi()->select_record( 'stats', { 'userid' => $user->{ 'id' } } );
    if ( $stat ) {
        $event eq 'public_ponies++'
            ? $stat->{ 'ponies' }++
            : $stat->{ 'ponies' }--;

        $self->dbi()->update_record( 'stats', $stat );
        return ( $event eq 'public_ponies++' 
            ? $self->respond( $message, "$name just got a pony!" ) 
            : $self->respond( $message, "$name just lost a pony!" )
        );
    }
    else {
        $self->respond( $message, "$name doesn't have any ponies." );
        return;
    }
}

1;

__END__
