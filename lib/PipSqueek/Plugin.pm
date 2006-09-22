package PipSqueek::Plugin;
use base 'Class::Accessor::Fast';
use strict;

# creates a new plugin instance
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = bless( {}, $class );

    $self->mk_accessors(qw(client _handlers _configuration));

    $self->client(shift);
    $self->_handlers({});
    $self->_configuration({});

    return $self;
}


sub config_initialize {} # called first when a new plugin is created
sub plugin_initialize {} # after config_initialize
sub plugin_teardown   {} # when a plugin is about to be destroyed


# a subclass will use this method to define the events to listen for and
# their associated handler methods
sub plugin_handlers 
{
    my $self = shift;
    my $hash = $self->_handlers();

    # Merges an arrayref or hashref with $hash
    # arrayrefs are merged as 'val1 => val1, val2=>val2' in the hash
    if( scalar(@_) )
    {
        my %data = ref($_[0]) eq 'HASH' ? %{$_[0]} :
                           ref($_[0]) eq 'ARRAY'? map{$_=>$_} @{$_[0]} : (@_);

        # before merge, replace multi_* handlers with private_* and
        # public_*
        foreach my $key ( keys %data )
        {
            if( $key =~ m/^multi_(.+)/ )
            {
                $data{"public_$1"}  = $data{$key};
                $data{"private_$1"} = $data{$key};

                delete $data{$key};
            }
        }

                %{ $hash } = ( %{ $hash }, %data );
        }

    return $self->_handlers($hash);
}

# a subclass will use this method to define the configuration parameters and
# default values which they accept
sub plugin_configuration
{
    my $self = shift;
    my $hash = $self->_configuration();

    if( scalar(@_) )
    {
        my %data = ref($_[0]) eq 'HASH' ? %{$_[0]} :
                           ref($_[0]) eq 'ARRAY'? map{$_=>$_} @{$_[0]} : (@_);

        %{ $hash } = ( %{ $hash }, %data );
    }

    return $self->_configuration($hash);
}


# shortcuts to access client variables
sub config  { return (shift)->client()->CONFIG();  }
sub dbi     { return (shift)->client()->DBI();     }


# shortcuts to access commonly used client routines
sub respond { return (shift)->client()->respond(@_); }
sub respond_act { return (shift)->client()->respond_act(@_); }
sub respond_user { return (shift)->client()->respond_user(@_); }


#------------------------------------------------------------------------------
# begin users database wrappers

# the 'users' database is just another database - but a lot of plugins
# require knowing information about a 'user', so we provide a nice little
# set of wrapper functions to facilitate easier plugin writing

# creates and returns a new user record based on the 'PipSqueek::Message' 
# object or username passed in
sub create_user
{
    my ($self,$target) = @_;

    my $username = ref($target) eq 'PipSqueek::Message' 
            ? $target->nick()
            : $target;

    return $self->dbi()->create_record( 'users',
        {
        'username' => $username,
        'nickname' => $username,
        'created'  => time()
        } 
    );
}


# returns a user record based on the parameters passed in (see PipSqueek::DBI)
sub select_user
{
    my $self = shift;
    return $self->dbi()->select_record( 'users', @_);
}


# updates (or creates) a user record in the database with the specified values
sub update_user
{
    my ($self,$target,$data) = @_;

    my $user = ref($target) eq 'HASH' 
            ? $target 
            : $self->search_or_create_user($target);

    $self->dbi()->update_record( 'users', $user, $data );
}


# deletes (or creates then deletes) a user record in the database with the
# specified values
sub delete_user
{
    my ($self,$target) = @_;

    my $user = ref($target) eq 'HASH' 
            ? $target 
            : $self->search_or_create_user($target);

    $self->dbi()->delete_record( 'users', $user );
}


# searches for a user according to the 'PipSqueek::Message' object or username
# passed in.  Can also return the correct user object even if the IRC user has
# changed nicknames and we tracked it
sub search_user
{
    my ($self,$target) = @_;

    if( ref($target) eq 'HASH' ) { return $target; }

    my $nick = ref($target) eq 'PipSqueek::Message'
            ? $target->nick()
            : $target;

    {
    my $sql  = 'SELECT * FROM users WHERE LOWER(nickname) = LOWER(?)';

    my $user = $self->dbi()->select_record( 'users', undef, $sql, $nick );
    return $user if $user;
    }

    {
    my $sql  = 'SELECT * FROM users WHERE LOWER(username) = LOWER(?)';

    my $user = $self->dbi()->select_record( 'users', undef, $sql, $nick );
    return $user if $user;
    }
}


# a simple convenience function which first looks for a user record, and if it
# finds none, then creates a new one and returns it
sub search_or_create_user
{
    my ($self,$target) = @_;

    if( my $user = $self->search_user($target) )
    {
        return $user;
    }

    return $self->create_user($target);
}

# end users database wrappers
#------------------------------------------------------------------------------


1; # module loaded successfully


__END__
