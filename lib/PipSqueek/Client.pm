package PipSqueek::Client;
use base 'Class::Accessor::Fast';
use strict;

use File::Find;
use File::Spec::Functions;
use FindBin qw($Bin);
use File::Path;

use PipSqueek::DBI;
use PipSqueek::Config;
use PipSqueek::Message;
use PipSqueek::Plugin;

use POE;
use POE::Component::IRC;


sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = bless( {}, $class );

    $self->mk_accessors(
        'DBI',
        'CONFIG',
        'PLUGINS',
        'REGISTRY',
        'ROOTPATH',
        'BASEPATH',
        'SESSION_ID',
        'IRC_CLIENT_ALIAS',
    );


    # initialize path information
    my $basepath = shift || die "No client path specified\n";
    my $rootpath = catdir( $Bin, '../' );

    $self->ROOTPATH( $rootpath );
    $self->BASEPATH( $basepath );


    unless( -d "$basepath/var" )
    {
        eval { mkpath("$basepath/var") };

        if( $@ ) {
            die "Couldn't make path: $basepath/var\n";
        }
    }

    # set up our DBI interface
    my $datafile = catfile( $basepath, '/var/pipsqueek.db' );
    my $dbi = 
        PipSqueek::DBI->new(
            "DBI:SQLite:$datafile",
            { 'RaiseError' => 1, 'AutoCommit' => 1 } 
        );
    $self->DBI( $dbi );


    # set up our configuration object
    my $config = PipSqueek::Config->new($rootpath,$basepath);
    
    # initialize the configuration object with defaults and keys we accept
    my $c_data = {
        'server_address'    => '',
        'server_port'        => '6667',
        'server_password'    => '',
        'server_channel'    => '#pipsqueek',
        'identity_nickname'    => 'PipSqueek',
        'identity_ident'    => 'pips',
        'identity_gecos'    => 'http://pipsqueek.net/',
        'local_address'        => '',
        'local_port'        => '',
        'public_command_prefix'    => '!',
        'answer_when_addressed'    => '1',
        'strip_privmsg_newlines'=> '1',
        'only_registered_users'    => '0',
        'default_access_level'    => '10',
        'require_identified_for_level' => '100',
        'default_kick_message'    => 'You\'reeeee outta here!',
        'default_ban_type'    => '4',
        'pipsqueek_version'    => 
            'PipSqueek v5: http://pipsqueek.net/',
    };

    $config->load_config( undef, $c_data );

    $self->CONFIG( $config );


    # initialize our list of loaded plugins
    $self->PLUGINS({});


    # initialize our plugin registry
    $self->REGISTRY({});


    # PoCo::IRC is stupid and requires an alias for the session
    # we use something completely random to appease it
    # (I would much rather just use the session ID, but oh well)
    $self->IRC_CLIENT_ALIAS( $$ + rand(5000) . time() );

    POE::Component::IRC->spawn( alias => $self->IRC_CLIENT_ALIAS() )
        or die "Failed to create P::C::I object: $!";

    # create the client session and store the session ID
    $self->SESSION_ID( $self->_create_session()->ID() );

    return $self;
}

# create_session
# initializes a new POE::Session instance and returns a reference to it
# NOTE: You shouldn't store the reference to the actual session since it
# will throw off POE::Kernel's automatic cleanup of unused sessions
sub _create_session
{
    my ($self) = @_;

    my @object_states = qw(
        _start 
        _stop 
        _default

        session_connect 
        session_disconnect
        session_keepalive
        session_shutdown

        plugin_register
        plugin_unregister

        plugins_load
        plugins_wipe

        plugin_delegate
    );

    return POE::Session->create(
        'args'    => [$self->IRC_CLIENT_ALIAS()],
        'heap'    => { 
            'start_time' => time()
            },
#        'options' =>  { 'trace' => 1 },
        'inline_states' => {},
        'object_states' => [
            $self => \@object_states
            ],
        'package_states' => [],

    ) or die "Failed to initialize POE Session: $!\n";
}


#------------------------------------------------------------------------------
# begin poe handlers 

# gets called upon creation of the POE::Session object (before the create() 
# call exits even).  Initialize various resources and register to receive
# events from the PoCo::IRC client
sub _start
{
    my ($kernel,$IRC_CLIENT_ALIAS) = @_[KERNEL, ARG0];

    $kernel->post( $IRC_CLIENT_ALIAS, 'register', 'all' );

    return 1;
}


# sent to our session when it's about to end
# NOTE: You cannot post new events to POE from here, since cleanup will
# remove them before they are ever executed
sub _stop
{
}


# catch events that were posted but did not have a predefined handler
# this makes it easier to write and debug event handlers
sub _default
{
    #print STDERR "\n";
    #print STDERR "Default caught an unhandled '$_[ARG0]' event.\n";
    #if( @{$_[ARG1]} ) {
    #    print STDERR "The '$_[ARG0]' event was given these params:\n";
    #    foreach my $param ( @{ $_[ARG1] } ) 
    #    {
    #        print STDERR "\t- $param\n" if defined($param);
    #    }
    #}
    #print STDERR "\n";

    # we should always return false to avoid catching system signals that
    # go unhandled (otherwise, we could only send SIGKILL and expect this
    # process to behave)
    return 0;
}


# an event handler for a PipSqueek::Session that tells the underlying PoCo::IRC
# client to connect using options specified (we supply useful defaults)
# 'options' should be a hashref to pass along to PoCo::IRC 
sub session_connect
{
    my ($self,$kernel,$options) = @_[OBJECT, KERNEL, ARG0];

    # Set sensible defaults
    $options->{'Server'}   ||= 'irc.topgamers.net';
    $options->{'Port'}     ||=  6667;
    $options->{'Nick'}     ||= 'PipSqueek';
    $options->{'Username'} ||= 'pips';
    $options->{'Ircname'}  ||= 'http://pipsqueek.net/';
    $options->{'Debug'}    ||= 1;

    # Fire off a connection event
    $kernel->post( $self->IRC_CLIENT_ALIAS(), 'connect', $options );
}


# an event handler for PipSqueek::Session that tells the underlying PoCo::IRC
# client to disconnect from the IRC server.  Can take an optional argument as
# the message to send the server for why we're disconnecting
sub session_disconnect
{
    my ($self,$kernel,$message) = @_[OBJECT, KERNEL, ARG0];

    $message ||= 'Session Terminated';

    $kernel->post( $self->IRC_CLIENT_ALIAS(), 'quit', $message );

    return 1;
}


# a recurring event that tells the PoCo::IRC client to ping the server
# this helps prevent timeouts during periods of inactivity
sub session_keepalive
{
    my ($self,$kernel,$seconds) = @_[OBJECT, KERNEL, ARG0];

    $seconds ||= 180; # default = 3 minutes

    # ping the server
    $kernel->post( $self->IRC_CLIENT_ALIAS(), 'sl', 'PING ' . time() );

    # set a new alarm to trigger this event again
    $kernel->delay_set( 'session_keepalive', $seconds, $seconds );

    return 1;
}


# an event handler for PipSqueek::Session that disconnects the IRC component 
# from the network, clears all loaded plugins, and makes ready to close down
sub session_shutdown
{
    my ($self,$kernel) = @_[OBJECT, KERNEL];

    $kernel->post( $self->SESSION_ID(), 'plugins_wipe' );
    $kernel->post( $self->SESSION_ID(), 'session_disconnect' );
    $kernel->post( $self->IRC_CLIENT_ALIAS(), 'unregister', 'all' );

    return 1;
}


# an event handler that registers a pipsqueek plugin's events
sub plugin_register
{
    my ($self,$session,$plugin) = @_[OBJECT, SESSION, ARG0];

#print "* Load plugin: ", ref($plugin), "\n";

    my $registry = $self->REGISTRY();
    my $handlers = $plugin->plugin_handlers();

    while( my ($event,$method) = each %$handlers )
    {
        my $metadata = {'obj' => $plugin, 'sub' => $method};

        $session->_register_state( $event, $self,  'plugin_delegate' )
            unless exists $registry->{$event};

        push( @{ $registry->{$event} }, $metadata );
    }

    return 1;
}


# an event handler which unregisters a pipsqueek plugin's events
sub plugin_unregister
{
    my ($self,$session,$plugin) = @_[OBJECT, SESSION, ARG0];

#print "* Unload plugin: ", ref($plugin), "\n";

    my $registry = $self->REGISTRY();
    my $handlers = $plugin->plugin_handlers();

    while( my ($event,$method) = each %$handlers )
    {
        my $r_events = $registry->{$event};
        my @x_delete = ();

        foreach my $x ( 0 .. $#$r_events )
        {
            my $meta = $r_events->[$x];
            if( ref($meta->{'obj'}) eq ref($plugin)
                && $meta->{'sub'} eq $method )
            {
                push(@x_delete,$x);
            }
        }

        foreach my $x ( @x_delete )
        {
            delete $registry->{$event}->[$x];
        }

        if( @$r_events == 0 ) 
        {
            $session->_register_state($event);
            delete $registry->{$event};
        }
    }

    return 1;
}


# searches through a local and root plugin directory for loadable modules
# and then sends those modules off to the session we're managing for loading
sub plugins_load
{
    my ($self,$kernel) = @_[OBJECT, KERNEL];

    # call() bypasses the FIFO event queue...
    $kernel->call( $self->SESSION_ID(), 'plugins_wipe' );

    my $plugins = $self->PLUGINS();
    my $config  = $self->CONFIG();

    # load the 'main' bot config before all else
    $config->load_config( '/etc/pipsqueek.conf' );
    
    find({ 'wanted' => 
    sub {
        $_ =~ s|^.*/||;
        return if /^\./ or $_ !~ /\.pm$/;
        return if $File::Find::name =~ /CVS/;
        return if $File::Find::dir !~ /Plugin$/;
        s/\.pm$//;
        
        $File::Find::name =~ s/bin\/..\///;

        my $module = "PipSqueek::Plugin::$_";
        return if exists $plugins->{$module};

        eval {
            delete $INC{$File::Find::name}; # unload
            require $File::Find::name;      # reload 

            # create new instance and initialize it
            my $plugin = $module->new( $self ); 

            $plugin->config_initialize();    # initialize config
            $config->load_config( $plugin ); #   "          "
    
            $plugin->plugin_initialize();  # initialize plugin

            $plugins->{$module} = $plugin; # store in registry

            $kernel->post( $self->SESSION_ID(), 'plugin_register',
                    $plugin );

            1;
        };

        warn "Failed to load $module: $@\n" if $@;

    }, 'no_chdir' => 1, },
    catdir( $self->BASEPATH(), 'lib/PipSqueek/Plugin' ),
    catdir( $self->ROOTPATH(), 'lib/PipSqueek/Plugin' ),
    );
    
    return 1;
}


# clears all the plugins we've registered and unregisters them from the session
sub plugins_wipe
{
    my ($self,$kernel) = @_[OBJECT, KERNEL];

    my $plugins = $self->PLUGINS();

    foreach my $plugin ( keys %$plugins )
    {
        $kernel->call( $self->SESSION_ID(), 'plugin_unregister', 
                $plugins->{$plugin} );
        $plugins->{$plugin}->plugin_teardown();
    }

    $self->PLUGINS({});
}


# this is the primary event handler for all registered plugins
# it takes the list of associated methods for this event and calls 
# them in the order they were loaded
sub plugin_delegate
{
    my ($self,$event,@args) = @_[OBJECT, STATE, ARG0 .. ARG9];

#    print "\n";
#    print time() . "\tEvent received: " . $event . "\n";

    my $registry = $self->REGISTRY();
    my $message;

    # pipsqueek_ events get special treatment
    unless( $event =~ /^pipsqueek_/ ) {
        $message = PipSqueek::Message->new($self->CONFIG(),$event,@args);
    }

    # call the handlers
    foreach my $metaobject ( @{ $registry->{"$event"} } )
    {
        my $plugin = $metaobject->{'obj'};
        my $method = $metaobject->{'sub'};

        if( $plugin->can( $method ) )
        {
            eval { 
                if( $event =~ /^pipsqueek_/ ) {
                    $plugin->$method( @args ); 
                } else {
                    $plugin->$method( $message );
                }
            };

            if( $@ ) {
                $@ =~ s/ at.*?$//;
                print "ERROR: $@\n";
                unless( $event =~ /^pipsqueek_/ ) 
                {
                    $self->respond($message, "ERROR: $@");
                }
            }
        }
        else
        {
            my $err =  "ERROR: Object method '$method' not found ".
                   "in " .ref($plugin);

            print "$err\n";

            unless( $event =~ /^pipsqueek_/ )
            {
                $self->respond( $message, $err );
            }
        }
    }

#    print time() . "\tEvent finished: " . $event . "\n";
#    print "\n";

    return 1;
}


# end poe handlers 
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# begin methods that allow us to communicate with POE sessions from the outside

# this lets us access the heap for our current session
sub get_heap
{
    return $poe_kernel->get_active_session()->get_heap();
}


# this lets us post events to the kernel from outside ourselves
sub post
{
    my $self = shift;
    $poe_kernel->post( @_ );
}


# this lets us post events to our own session from outside ourselves
sub yield
{
    my $self = shift;
    $poe_kernel->post( $self->SESSION_ID(), @_ );
}


# this lets other objects access the poe kernel without having to 'use POE'
sub kernel
{
    return $poe_kernel;
}


# end outside_word->poe communication routines
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# begin convenience function wrappers to the PoCo::IRC client

# allows a plugin writer to forget about what 'context' (public or private)
# they're in and just respond to the message
sub respond
{
    my ($self,$message,@rest) = @_;

    my $target = $self->CONFIG()->server_channel();

    if( $message->event() =~ /^private/ 
        || $message->event() eq 'irc_msg' )
    {
        $target = $message->nick();
    }
    elsif( $message->event() =~ /^public/ 
        || $message->event() eq 'irc_public' )
    {
        $target = $message->channel() || $target;
    }

    $self->privmsg( $target, @rest );

    return 1;
}


# see above description, just uses a /me instead of privmsg
sub respond_act
{
    my ($self,$message,@rest) = @_;

    my $target = $self->CONFIG()->server_channel();

    if( $message->event() =~ /^private/
        || $message->event() eq 'irc_msg' )
    {
        $target = $message->nick();
    }
    elsif( $message->event() =~ /^public/
        || $message->event() eq 'irc_public' )
    {
        $target = $message->channel() || $target;
    }

    $self->ctcp( $target, "ACTION @rest" );

    return 1;
}


# see description for respond, but this one prepends the nickname of the user
# that we're responding to
sub respond_user
{
    my ($self,$message,$one) = @_;

    my $nickname = $message->nick();

    return $self->respond( $message, "$nickname: $one", @_[3..$#_] );
}


# sends a CTCP (client to client protocol) message 
sub ctcp    
{
    my $self = shift;

    # tells our session that we're sending a /me
    if( $_[1] =~ /^ACTION/ )
    {
        my ($target,$text,@rest) = @_;
           $text =~ s/^ACTION //;
        $poe_kernel->post( $self->SESSION_ID(), 'sentact', 
                   $self->CONFIG()->current_nickname(),
                   [$target], $text, @rest );
    }

    $self->_pass_args(@_);
}


# most of the PoCo:IRC events take the same arguments, this simplifies 
# writing wrappers around them a bit
sub _pass_args
{
    my $self = shift;
    my (undef,undef,undef,$name) = caller(1);

    $name =~ s/^.*:://;
    $poe_kernel->post( $self->IRC_CLIENT_ALIAS(), $name, @_ );

    return 1;
}

# wrappers around common PoCo::IRC events
sub ctcpreply  { (shift)->_pass_args(@_) }
sub join       { (shift)->_pass_args(@_) }
sub mode       { (shift)->_pass_args(@_) }
sub notice     { (shift)->_pass_args(@_) }
sub part       { (shift)->_pass_args(@_) }
sub quit       { (shift)->_pass_args(@_) }
sub sl         { (shift)->_pass_args(@_) }
sub topic      { (shift)->_pass_args(@_) }
sub whois      { (shift)->_pass_args(@_) }
sub invite     { (shift)->_pass_args(@_) }
sub who        { (shift)->_pass_args(@_) }
sub names      { (shift)->_pass_args(@_) }
sub list       { (shift)->_pass_args(@_) }

sub nick 
{
    my $self = shift;

    $self->CONFIG()->current_nickname($_[0]);

    $poe_kernel->post( $self->IRC_CLIENT_ALIAS(), 'nick', @_ );
}


# removes a user from the channel forcibly
sub kick 
{
    my ($self,$channel,$target,$message) = @_;

    unless( defined($message) && $message ne "" )
    {
        $message = $self->CONFIG()->default_kick_message();

        if( defined($message) && -e $message )
        {
            if( open(my $fh, '<', $message) )
            {
                my @slurp = <$fh>;
                chomp(@slurp);
                $message = @slurp[rand @slurp];
                close( $fh );
            }
            else
            {
                warn "Error reading kick message file: $!\n";
            }
        }
    }

    $poe_kernel->post( $self->IRC_CLIENT_ALIAS(), 
               'kick', $channel, $target, $message );
}


# sends a private message to the target destination
# automatically breaks the message up into multiple messages if it is too long
# to fit into a standard IRC protocol datagram
sub privmsg 
{ 
    my ($self,$target,@input) = @_;
    my $input = "@input";

    if( $self->CONFIG()->strip_privmsg_newlines() )
    {
        $input =~ s/^(.*?)[\n\r]+.*$/$1/s;
    }

    my $maxlen = 512 - 76 - length(": PRIVMSG $target :\r\n");
    # the 76 is to take into account the ident@host sent back to other
    # clients when a message is transmitted, ident is 11 chars, host is 64,
    # 1 for '@'.

    my $nickname = $self->CONFIG()->current_nickname();

    unless( length($input) > $maxlen )
    {
        # send the message
        $poe_kernel->post( $self->IRC_CLIENT_ALIAS(), 
                   'privmsg', $target, $input);
        
        # inform our session we're sending the message
        $poe_kernel->post( $self->SESSION_ID(), 
                   'sentmsg', $nickname, [$target], $input );
        return;
    }

    # continue while we still have data to match
    while( my ($message) = $input =~ m/^(.{1,$maxlen})/ )
    {
        # is there more to send still after this match?
        if( length($message) != length($input) )
        {
            # break the message on spacing (only send everything up
            # to the last space available)
            $message =~ s/^(.*)\s+.*?$/$1/;
        }

        # strip the message we'll be sending from the remaining input
        $input =~ s/^\Q$message\E\s*//;

        # bon voyage, mon ami
        $poe_kernel->post( $self->IRC_CLIENT_ALIAS(),
                   'privmsg', $target, $message);

        # inform our session we're on our way
        $poe_kernel->post( $self->SESSION_ID(), 
                   'sentmsg', $nickname, [$target], $message );
    }
}


1;


__END__
