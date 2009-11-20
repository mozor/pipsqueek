package PipSqueek::Plugin::Admin;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'multi_rehash',
        'multi_topic',
        'multi_say',
        'multi_act',
        'multi_raw',
        'multi_part',
        'multi_join',
        'multi_cycle',
        'multi_setlevel',
        'multi_shutdown',
        'multi_kick',
        'multi_ban',
        'multi_mode',
        'multi_invite',
        'multi_mergeuser',
		'multi_prune',
    ]);
}


sub multi_rehash
{
    my ($self,$message) = @_;

    $self->client()->kernel()->call( $self->client()->SESSION_ID(),
                     'plugins_load' );

    return $self->respond( $message, "Bot rehashed" );
}


sub multi_topic
{
    my ($self,$message) = @_;
    my ($channel,$topic) = $message->command_input() =~
        m/^(?:([#&+!].*?)\s+)?(.*)$/;
    $channel ||= $self->config()->server_channel();

    $self->client()->topic( $channel, $topic );
}


sub multi_say
{
    my ($self,$message) = @_;
    my ($channel,$text) = $message->command_input() =~
        m/^(?:([#&+!].*?)\s+)?(.*)$/;
    $channel ||= $self->config()->server_channel();

    $self->client()->privmsg( $channel, $text );
}


sub multi_act
{
    my ($self,$message) = @_;
    my ($channel,$text) = $message->command_input() =~
        m/^(?:([#&+!].*?)\s+)?(.*)$/;
    $channel ||= $self->config()->server_channel();

    $self->client()->ctcp( $channel, "ACTION $text" );
}


sub multi_raw
{
    my ($self,$message) = @_;
    my ($raw) = $message->command_input() || return;
    $self->client()->sl( $raw );
}


sub multi_kick
{
    my ($self,$message) = @_;
    my ($user,$channel,$msg) = $message->command_input() =~ 
        m/^(.+?)(?:\s+([#&+!].+?))?(?:\s+(.+))?$/;

    $channel ||= $self->config()->server_channel();

    return unless $user;

    $self->client()->kick( $channel, $user, $msg );
}


sub multi_part
{
    my ($self,$message) = @_;
    my $channel = $message->command_input() 
            || $self->config()->server_channel();
    $self->client()->part( $channel );
}


sub multi_join
{
    my ($self,$message) = @_;
    my $channel = $message->command_input()
            || $self->config()->server_channel();
    $self->client()->join( $channel );
}


sub multi_cycle
{
    my ($self,$message) = @_;
    my $channel = $message->command_input()
            || $self->config()->server_channel();
    $self->client()->part( $channel );
    $self->client()->join( $channel );
}


sub multi_shutdown
{
    my ($self,$message) = @_;

    $self->client()->yield( 'session_shutdown' );
}
        

sub multi_ban
{
    my ($self,$message) = @_;
    my ($name,$channel,$mode) = split(/\s+/, $message->command_input());

    if( !$mode && $channel =~ /^[\d]$/ )
    {
        $mode = $channel;
        $channel = undef;
    }

    $channel ||= $self->config()->server_channel();
    $mode ||= $self->config()->default_ban_type() || 4;

    my $user = $self->search_user( $name );

    my ($ident,$host);

    if( $user ) {
        $ident = $user->{'ident'};
        $host  = $user->{'host'};
        $ident =~ s/^~//;
    } else {
        $mode = 1;
    }
    

    my $ban;
    foreach ( $mode )
    {
           if( /1/ ) { $ban = qq(*$name!*\@*) }
        elsif( /2/ ) { $ban = qq(*!*$ident\@*) }
        elsif( /3/ ) { $ban = qq(*$name!*$ident\@*) }
        elsif( /4/ ) {
            $host =~ s/^.*?\./*./;
            $ban = qq(*!*\@$host);
        }
        elsif( /5/ ) {
            $host =~ s/^.*?\./*./;
            $ban = qq(*$name!*\@$host);
        }
        elsif( /6/ ) {
            $host =~ s/^.*?\./*./;
            $ban = qq(*!*$ident\@$host);
        }
        elsif( /7/ ) {
            $host =~ s/^.*?\./*./;
            $ban = qq(*$name!*$ident\@$host);
        }
    }

    $self->client()->mode( $channel, '+b', $ban );
}


sub multi_mode
{
    my ($self,$message) = @_;
    my @args = split( /\s/, $message->command_input() );

    $self->client()->mode( @args );
}


sub multi_invite
{
    my ($self,$message) = @_;
    my ($nickname,$channel) = split(/\s+/,$message->command_input());

    $channel ||= $self->config()->server_channel();

    if( !defined($nickname) || $nickname eq "" )
    {
        $self->respond( $message, "See !help invite" );
        return;
    }

    $self->client()->invite( $nickname, $channel );
}


sub multi_setlevel
{
    my ($self,$message) = @_;
    my ($name,$level) = split( /\s+/, $message->command_input() );

    if( $name && defined($level) )
    {
        my $user = $self->search_user( $name );

        unless( $user )
        {
            $self->respond( $message, "That user does not exist" );
            return;
        }
        
        $user->{'cmd_level'} = $level;

        $self->update_user( $user );
    }
}


sub multi_mergeuser
{
    my ($self,$message) = @_;
    my ($u1name,$u2name) = split(/\s+/,$message->command_input());

    unless( defined($u1name) && defined($u2name) )
    {
        $self->respond( $message, "See !help mergeuser" );
        return;
    }

    my $user1 = $self->search_user($u1name);
    my $user2 = $self->search_user($u2name);

    unless( defined($user1) && $user1->{'id'} )
    {
        $self->respond( $message, "User not found: '$u1name'" );
        return;
    }

    unless( defined($user2) && $user2->{'id'} )
    {
        $self->respond( $message, "User not found: '$u2name'" );
        return;
    }

    if( $user1->{'id'} == $user2->{'id'} )
    {
        $self->respond( $message, 
            "You can't merge a user with himself" );
        return;
    }
    
    
    $self->client()->yield( 'pipsqueek_mergeuser', $message, 
                $user1, $user2 );

    $self->respond( $message, "'mergeuser' event dispatched.  It could take a few seconds for all data to be updated" );

    return;
}


# Somehow we ran into a bug where multiple records were created for the same
# username, which resulted in all sorts of oddities.  This routine helped sort
# some of it out.
# finds all duplicate usernames and merges them
sub multi_prune
{
    my ($self,$message) = @_;

	my $dbh = $self->dbi()->dbh();
	my $sth = $dbh->prepare('SELECT id, username FROM users ORDER BY id');
	   $sth->execute();
	
	$self->respond($message, "Acknowledged");

	my $data = {};
	while (my ($id, $name) = $sth->fetchrow_array()) {
		$name =~ s/_+$//;
		push @{$data->{$name}}, $id;
	}
	
	$self->respond($message, sprintf("Fetched %d records", scalar(keys %$data)));

	foreach my $name (keys %$data) {
		next unless @{$data->{$name}} > 1;
		
		$self->respond($message, "$name has more than one similar ID");

		my $sql = 'SELECT * FROM users WHERE id = ?';
		my $user1 = $self->dbi()->select_record(
				'users', undef, $sql, $data->{$name}->[0]
		);

		while (@{$data->{$name}} > 1) {
			my $user2 = $self->dbi()->select_record(
				 'users', undef, $sql, pop @{$data->{$name}}
			);
			
			$self->client()->yield(
				'pipsqueek_mergeuser', $message, $user1, $user2
			);

			$self->respond($message, "Merging $user2->{'id'} ($user2->{'username'}) into $user1->{'id'}");
		}
	}
	
	$self->respond($message, "Done");

    return;
}

1;


__END__
