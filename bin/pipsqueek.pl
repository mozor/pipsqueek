#!/usr/bin/perl
use strict;
use warnings;

use File::Spec::Functions qw(catfile catdir);
use FindBin qw($Bin);
use Getopt::Long;
use Pod::Usage;
use POE;

use lib "$Bin/../lib";
use PipSqueek::Client;
use PipSqueek::Jabber_Client;

my @clients;

# go! ####
sub main
{
    my @dirs = &parse_command_line();

    # create our dating profile so sexy programs know where to find us
    my $pidfile = catfile( catdir( $Bin, '../' ), '/var/pipsqueek.pid' );
    open( my $pfh, '>', $pidfile )
        or die "Unable to write pidfile: $!\n";
    print $pfh $$;
    close( $pfh );

    # create a new client for every argument passed in our client config
    foreach my $dir ( @dirs )
    {
        my $client = PipSqueek::Client->new( $dir );
        push(@clients,$client);
    }

    my $client = PipSqueek::Jabber_Client->new($dirs[0]);
    if (ref($client)) {push(@clients,$client);}

    # start our primary poe session
    POE::Session->create(
        'args'      => [],
        'heap'    => {},
        'options' => {},
        'inline_states'  => { 
            '_start' => \&_start,
            'pipsqueek_signal' => \&pipsqueek_signal,
        },
        'object_states'  => [],    
        'package_states' => [],
    )
    or die "Failed to initialize POE::Session: $!\n";

    # away we go...
    $poe_kernel->run();

    unlink( $pidfile );

    return 0;
}


# reads the command line arguments using Getopt::Long
sub parse_command_line
{
    my $help;
    my @dirs;

    my $parser = Getopt::Long::Parser->new();
       $parser->configure( 'bundling' );
       $parser->getoptions(
           'help|h|?' => \$help,
        'clientdir|d=s' => \@dirs,
       ) or pod2usage(2);
    
    pod2usage(1) if $help;

    # get the dirs as space-separated values from the command line
    # return them
    unless( @dirs )
    {
        pod2usage(1) unless @ARGV;
        @dirs = @ARGV;
    }

    @dirs = split( /\s*,\s*/, join(',',@dirs) );

    return @dirs;
}


# called once our POE::Session is active, initialize and connect our clients
sub _start
{
    my ($kernel) = $_[KERNEL];

    $kernel->alias_set( 'pipsqueek' );

    $kernel->sig( 'HUP',  'pipsqueek_signal' );
    $kernel->sig( 'TERM', 'pipsqueek_signal' );
    $kernel->sig( 'INT',  'pipsqueek_signal' );

    foreach my $client ( @clients )
    {
        $kernel->call( $client->SESSION_ID(), 'plugins_load' );
        
        # configure connection
        my $config = $client->CONFIG();
      my $options;
      if ($client->can('IRC_CLIENT_ALIAS')) {
        $options = {
            'Server'    => $config->server_address(),
            'Password'  => $config->server_password(),
            'Port'      => $config->server_port(),
            'LocalAddr' => $config->local_address(),
            'LocalPort' => $config->local_port(),
            'Nick'      => $config->identity_nickname(),
            'Username'  => $config->identity_ident(),
            'Ircname'   => $config->identity_gecos(),
        };
       }

        # connect session
        $kernel->post( $client->SESSION_ID(), 'session_connect', 
                $options );
    }

    return 1;
}


# called when the program receives a signal we've registered for
sub pipsqueek_signal
{
    my ($kernel,$signal) = @_[KERNEL, ARG0];

    $kernel->sig_handled();

    # SIGHUP, we will reload all plugins
    if( $signal eq 'HUP' )
    {
        foreach my $client ( @clients )
        {
            $kernel->call( $client->SESSION_ID(), 'plugins_load' );
        }
    }
    # SIGTERM or SIGINT, we will shutdown gracefully
    elsif( $signal eq 'TERM' || $signal eq 'INT' )
    {
        foreach my $client ( @clients )
        {
            $kernel->post( $client->SESSION_ID(), 
                    'session_shutdown' );
        }
    }
}


exit( &main(@ARGV) );


__END__

=head1 NAME
pipsqueek - perl IRC bot

=head1 SYNOPSIS

pipsqueek [options] [--clientdir] clientdir[, clientdir, ... ]

  Options:
  --help -? -h      brief help message

  --clientdir -d    a comma-separated list of directories which contain a 
                    standard pipsqueek configuration.  Instead of using -d,
                    you can also just pass the directories as arguments to
                    the script

=head1 DESCRIPTION

B<PipSqueek> is a perl IRC bot with many features.  See http://pipsqueek.net/

=cut

