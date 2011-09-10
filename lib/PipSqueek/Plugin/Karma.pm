package PipSqueek::Plugin::Karma;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
	my $self = shift;
	
	$self->plugin_handlers(
		'public_stars++' => 'multi_karma',
		'public_stars--' => 'multi_karma',
		
		'pipsqueek_mergeuser' => 'pipsqueek_mergeuser',
	);
}

sub multi_karma
{
	
	my ($self,$message) = @_;
	my $name = $message->command_input();
	my $event = $message->event();
	my $sender = $self->search_or_create_user( $message );
	
	if( $name )
    {
        $user = $self->search_user( $name );
        unless( $user )
        {
            $self->respond( $message, "That user does not exist" );
            return;
        }
    }
	
	if( $name eq lc($sender->{'username'})
     || $name eq lc($sender->{'nickname'}) )
	{
		$self->respond( $message, "You can't give yourself a gold star!" );
		return;
	}
	
	my $stat = $self->dbi()->select_record('stats',{'userid'=>$user->{'id'}});
    if( $stat )
    {
        $event eq 'public_stars++' 
            ? $stat->{'stars'}++ 
            : $stat->{'stars'}--;

        $self->dbi()->update_record( 'stats', $stat );
		return $self->respond( $message, "$name has had their star count updated" );
    }
    else
    {
        $self->respond( $message, "Stars could not be found for $name." );
        return;
    }
}



1;


__END__