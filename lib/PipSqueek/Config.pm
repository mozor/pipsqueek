package PipSqueek::Config;
use base 'Class::Accessor::Fast';

use File::Spec::Functions;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = bless( {}, $class );

    my ($root,$path) = @_;

    unless( $root && $path )
    {
        die "Must give configuration object a root and local path " .
            "to search for appropriate configuration data";
    }

    # these are a couple of internal (non-configurable) parameters
    $self->mk_accessors( 'current_nickname', '_root', '_path' );

    $self->_root( $root );
    $self->_path( $path );

    return $self;
}


# This method has 3 possible uses:
#    1) Pass a PipSqueek::Plugin object in, and it will use the plugin's
#       methods to extract valid configuration keys, then look for the
#       appropriate configuration files
#    2) Pass a filename as the first argument and a hashref of the valid
#       keys / default values for the configuration params.  Then it will
#       load the named file from the root directory and config directory
#    3) Pass 'undef' as the first argument and a hashref as the second.
#       It will load the key/default values from the hashref and then return
sub load_config
{
    my ($self,$thing,$data) = @_;

    my $filename = $thing;
    my $config   = $data;

    if( ref($thing) =~ m/^PipSqueek::Plugin::/ )
    {
        $filename = ref($thing);
        $filename =~ s/^PipSqueek::Plugin:://;
        $filename = "etc/plugins/$filename.conf";

        # load the default configuration keys:
        $config = $thing->plugin_configuration();
    }

    if( defined($config) && ref($config) eq 'HASH' )
    {
        my @keys = keys %$config;
        $self->mk_accessors(@keys);

        foreach my $key (@keys)
        {
            $self->$key( $config->{$key} );
        }
    }

    return unless defined $filename;

    my $loaded = 0;

    foreach my $dir ( $self->_root(), $self->_path() )
    {
        my $file = catfile($dir,$filename);

        if( -e $file ) 
        {
            $loaded = $self->_merge_config_file( $file );
        }
    }

    return $loaded;
}


# parses an actual configuration file and stores values
sub _merge_config_file
{
    my ($self,$filename) = @_;

    open( my $fh, '<', $filename )
        or die "Unable to read '$filename': $!\n";
    my @lines = grep {!/^\s*#/} <$fh>;
    chomp(@lines);
    close( $fh );

    foreach my $line ( @lines )
    {
        next unless $line =~ /[^\s]/;

        # parse out a simple key=value
        my ($k,$v) = $line =~ /^\s*(.+?)\s*[=:\t]\s*(.+?)\s*;?\s*$/;

        # trim whitespace on key
        $k =~ s/^\s*|\s*$//g;

        if( $v =~ /^\s*["'](.*?)['"]\s*;?$/ )
        # grab everything in between the outermost quotes
        {
            $v = $1;
        } 
        else
        # doesn't have quoted data
        {
            # trim whitespace on value
            $v =~ s/^\s*|\s*$//g;
        }

        if( $self->can($k) )
        {
            $self->$k( $v );
        }
        else
        {
            warn "Invalid config key: $k (from $filename)\n";
        }
    }

    return 1;
}


1;


__END__
