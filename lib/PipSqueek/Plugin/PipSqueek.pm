package PipSqueek::Plugin::PipSqueek;
use base 'PipSqueek::Plugin';
use strict;

# This plugin defines the basic operations of the pipsqueek bot

# things like command delegation, user registration/user management, 
# user authorization, and some ctcp replies are handled here

use File::Spec::Functions qw(catfile);


sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'irc_msg',
        'irc_public',
        
        'irc_001', # server welcome message
        'irc_433', # nickname is in use
        'irc_error',
        'irc_disconnected',

        'irc_ctcp_version',
        'irc_ctcp_ping',
        
        'irc_join', # for user tracking
        'irc_part',
        'irc_quit',
        'irc_nick',
        'irc_kick',
        'irc_353',  # NAMES list on entering

        'private_register', # for users
        'private_identify',

        'pipsqueek_mergeuser',
    ]);

    $self->_load_levels_conf();

    # set up our database table for users
    my $schema = [
        [ 'id',     'INTEGER PRIMARY KEY' ],
        [ 'username',    'VARCHAR NOT NULL' ],
        [ 'nickname',    'VARCHAR NOT NULL' ],
        [ 'ident',    'VARCHAR' ],
        [ 'host',    'VARCHAR' ],
        [ 'password',     'VARCHAR' ],
        [ 'logged_in',    'INT NOT NULL DEFAULT 0' ],
        [ 'identified',    'INT NOT NULL DEFAULT 0' ],
        [ 'last_seen',    'TIMESTAMP' ],
        [ 'seen_data',    'VARCHAR' ],
        [ 'created',    'TIMESTAMP NOT NULL' ],
        [ 'cmd_level',    'INT NOT NULL DEFAULT 10' ],
    ];

    $self->dbi()->install_schema( 'users', $schema );
}


#-- user registration stuff --#
sub private_register
{
    my ($self,$message) = @_;

    my $user = $self->search_or_create_user( $message );

    if( $user->{'password'} )
    {
        $self->respond( $message, 
            "This account is already registered" );
        return;
    }

    my ($password,$username) = split( /\s+/, $message->command_input() );

    unless( defined($password) && defined($username) )
    {
        $self->respond( $message, "Use !help register" );
        return;
    }

    $user->{'password'} = $password;
    $user->{'username'} = $username;
    $user->{'identified'} = 1;

    $self->update_user( $user );

    $self->respond( $message, "Ahoy! You are now registered" );
}


sub private_identify
{
    my ($self, $message ) = @_;

    my $user = $self->search_or_create_user( $message );

    unless( $user->{'password'} )
    {
        $self->respond( $message, 
            "Your account is not yet registered" );
        return;
    }

    my $password = $message->command_input();

    if( defined($password) && $user->{'password'} eq $password )
    {
        $user->{'identified'} = 1;
        $self->respond( $message, "You are now identified" );
        $self->update_user( $user );
        return;
    }

    $self->respond( $message, "Identification failed" );
    return;
}


# pipsqueek_mergeuser is a POE event that means we're supposed to take
# two user records, merge the second into the first and delete the second
sub pipsqueek_mergeuser
{
    my ($self,$message,$user1,$user2) = @_;

    # we don't have anything to merge, so we just delete the second
    $self->delete_user($user2);
}



#-- command delegation and authorization --#
sub irc_msg    { (shift)->_delegate_command(@_) }
sub irc_public 
{
    my ($self,$message) = @_;
    my $msg = $message->message();

    $self->update_user( $message, {
        'last_seen' => time(),
        'seen_data' => "saying: $msg",
        'ident' => $message->ident(),
        'host' => $message->host(),
    } );

    (shift)->_delegate_command(@_);
}

sub _delegate_command
{
    my ($self,$message) = @_;
    return unless $message->is_command();
    
    my $command = $message->command();
    my $client  = $self->client();
    my $config  = $self->config();

    my $c_access = $config->default_access_level();
    my $c_regist = $config->only_registered_users();
    my $c_identi = $config->require_identified_for_level();

    my $user  = $self->search_or_create_user($message);
    my $level = $self->{'LEVELS'}->{$command} || $c_access;

    if( $user->{'cmd_level'} < $level )
    # Are they authorized for this command?
    {
        $self->client()->privmsg( $message->nick(), 
        "This command requires a command level of $level. " .
        "You currently have a level of $user->{'cmd_level'}" );

        return;
    }

    if( $c_regist )
    # do we require the user to be registered for this command?
    {
        unless( $command eq 'register' || $user->{'password'} )
        {
            $self->client()->privmsg( $message->nick(),
            "You must be registered to use _any_ command" );
            return;
        }
    }

    if( $level >= $c_identi )
    # do we require the user to be identified for this command?
    {
        unless( $command eq 'identify' || $user->{'identified'} )
        {
            $self->client()->privmsg( $message->nick(),
            "You must be identified to use that command" );
            return;
        }
    }

    # and finally, dispatch the event
    if( $message->event() eq 'irc_msg' )
    {
        $self->client()->yield("private_$command",@{$message->raw()});
    }
    elsif( $message->event() eq 'irc_public' )
    {
        $self->client()->yield("public_$command", @{$message->raw()});
    }
}


#-- various ctcp replies --#
sub irc_ctcp_version
{
    my ($self,$message) = @_;

    $self->client()->ctcpreply( 
        $message->nick(), 
        'VERSION ' . $self->config()->pipsqueek_version() 
    );
}


sub irc_ctcp_ping
{
    my ($self,$message) = @_;

    $self->client()->ctcpreply(
        $message->nick(),
        'PING ' . $message->message() 
    );
}


#-- server connection handlers --#
sub irc_error
{
    my ($self,$message) = @_;
    print "Server error: ", $message->message(), "\n";
}


sub irc_disconnected
{
    my ($self,$message) = @_;

    my $config = $self->config();
    my $options = {
        'Server'    => $config->server_address(),
        'Password'  => $config->server_password(),
        'Port'      => $config->server_port(),
        'LocalAddr' => $config->local_address(),
        'LocalPort' => $config->local_port(),
        'Nick'      => $config->identity_nickname(),
        'Username'  => $config->identity_ident(),
        'Ircname'   => $config->identity_gecos(),
    };

    $self->client()->yield( 'session_connect', $options );
}


sub irc_001
{
    my ($self,$message) = @_;
    my $client = $self->client();
    my $config = $self->config();

    # all users are no longer logged_in
    $self->dbi()->update_record( 'users', undef, 
        { 'logged_in' => 0,
          'identified' => 0, }
    );

    $config->current_nickname( $config->identity_nickname() );

    # most networks require us to identify ourselves as a bot with mode +B
    $client->mode( $config->identity_nickname(), '+B' );

    # join up!
    $client->join( $config->server_channel() );
}


sub irc_433
{
    my ($self,$message) = @_;
    my $client = $self->client();
    my $config = $self->config();

    $client->nick( $config->identity_nickname() . '_' );
    $client->join( $config->server_channel() );
}


#-- various user tracking handlers --#
sub irc_join
{
    my ($self,$message) = @_;

    $self->update_user( $message, 
        {
        'logged_in' => 1,
        'last_seen' => time(),
        'seen_data' => 'joining the channel',
        'ident' => $message->ident(),
        'host' => $message->host(),
        }
    );
}


sub irc_part
{
    my ($self,$message) = @_;
    my $msg = $message->message();

    $self->update_user( $message, { 
        'logged_in' => 0, 
        'identified' => 0,
        'last_seen' => time(),
        'seen_data' => "leaving the channel with message: $msg",
        'ident' => $message->ident(),
        'host' => $message->host(),
    } );
}


sub irc_kick
{
    my ($self,$message) = @_;
    my $target = $message->recipients();
    my $msg    = $message->message();

    $self->update_user( $target, { 
        'logged_in' => 0,
        'identified' => 0,
        'last_seen' => time(),
        'seen_data' => "being kicked with message: $msg",
    } );
}


sub irc_quit
{
    my ($self,$message) = @_;

    my $msg = $message->message();

    $self->update_user( $message, {
        'logged_in' => 0, 
        'identified' => 0,
        'last_seen' => time(),
        'seen_data' => "quitting the server with message: $msg",
    } );
}


sub irc_nick
{
    my ($self,$message) = @_;

    my $from = $message->nick();
    my $to   = $message->message();

    if( my $user = $self->search_user($to) )
    {
        $self->update_user( $from, { 'logged_in' => 0 } );
        $self->update_user( $user, {
            'nickname' => $message->message(),
            'logged_in' => 1,
            'last_seen' => time(),
            'seen_data' => "changing nicks from $from to $to",
        } );
    }
    else
    {
        $self->update_user( $message, {
            'nickname' => $message->message(),
            'last_seen' => time(),
            'seen_data' => "changing nicks from $from to $to",
        } );
    }
}


sub irc_353
{
    my ($self,$message) = @_;

    foreach my $name ( @{ $message->recipients() } )
    {
        $name =~ s/^.// if $name =~ /^[%&+@~^]/;

        $self->update_user( $name, {
            'logged_in' => 1,
        } );
    }
}


#-- some helper functions --#
sub _load_levels_conf
{
    my $self = shift;
    my $client = $self->client();

    my $loaded = 0;

    foreach my $dir ( $client->ROOTPATH(), $client->BASEPATH() )
    {
        my $file = catfile( $dir, '/etc/levels.conf' );

        if( -e $file ) 
        {
            $self->_merge_levels_conf_file( $file );
            $loaded = 1;
        }
    }

    unless( $loaded )
    {
        warn "Unable to find levels.conf for " .
            $self->config()->server_channel() . "\n";
    }
}

sub _merge_levels_conf_file
{
    my ($self,$file) = @_;

    open( my $fh, '<', $file )
        or die "Unable to open '$file': $!";
    my @lines = <$fh>;
    chomp(@lines);
    close( $fh );

    foreach my $line (grep(/=/,@lines))
    {
        my ($k,$v) = split(/=/,$line);
        $self->{'LEVELS'}->{$k} = $v;
    }
}


1;


__END__
