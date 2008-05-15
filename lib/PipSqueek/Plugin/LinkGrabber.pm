package PipSqueek::Plugin::LinkGrabber;
use base qw(PipSqueek::Plugin);

use URI::Find::Schemeless;


sub config_initialize
{
    my $self = shift;

    $self->plugin_configuration({
        'linkgrabber_default' => 3,
        'linkgrabber_maximum' => 6,
        'linkgrabber_private_maximum' => 25,
    });
}



sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'irc_public',
        'multi_urls',
        'multi_links',
        'pipsqueek_mergeuser',
    ]);

    my $schema = [
        [ 'id',        'INTEGER PRIMARY KEY' ],
        [ 'userid',    'INT NOT NULL' ],
        [ 'time',    'INT NOT NULL DEFAULT 0' ],
        [ 'url',    'VARCHAR NOT NULL' ],
    ];

    $self->dbi()->install_schema( 'linkgrabber', $schema );
}


sub irc_public
{
    my ($self,$message) = @_;

    my $user = $self->search_user( $message );
    my $text = $message->message();

    my $finder = URI::Find::Schemeless->new( 
        sub { $self->add_url( $user, @_ ); } 
    );

    my $count = $finder->find( \$text );

    return;
}


sub add_url
{
    my ($self,$user,$uri,$orig_uri) = @_;
    my $url = $uri->as_string();

    $self->dbi()->create_record( 'linkgrabber', 
        {
        'url' => $url,
        'time' => time(),
        'userid' => $user->{'id'},
        } 
    );
}


sub multi_links {
    (shift)->multi_urls(@_);
}

sub multi_urls
{
    my ($self,$message) = @_;
    my ($name, $amount) = split /\s+/, $message->command_input();

    if ($name =~ /^-?\d+$/) {
        ($amount,$name) = ($name,$amount);
    }

    if ($name =~ /^[^\d+]$/) 
    {
        $amount = $default;
    }

    my $config = $self->config();
    my $default = $config->linkgrabber_default();
    my $maximum = $message->event() =~ /^private_/ 
            ? $config->linkgrabber_private_maximum()
            : $config->linkgrabber_maximum();

    $amount ||= $default;
    $amount = $maximum if $amount > $maximum;
    $amount = $default if $amount < 1;

    my @links = ();

    if( $name )
    {
        my $user = $self->search_user($name);

        unless( $user )
        {
            $self->respond($message, "That user does not exist.");
            return;
        }

        my $sql = 'SELECT url FROM linkgrabber WHERE userid=? ' .
              "ORDER BY time DESC LIMIT $amount";
        my $sth = $self->dbi()->dbh()->prepare($sql);
           $sth->execute( $user->{'id'} );

        @links = map { $_->[0] } @{$sth->fetchall_arrayref()};
    }
    else
    {
        my $sql = 'SELECT url FROM linkgrabber ' .
              "ORDER BY time DESC LIMIT $amount";
        my $sth = $self->dbi()->dbh()->prepare($sql);
           $sth->execute();

        @links = map { $_->[0] } @{$sth->fetchall_arrayref()};
    }

    if( @links )
    {
        local $" = ' - ';
        my $s = $amount == 1 ? "" : 's';

        $self->respond( $message, "Last $amount URL$s" . 
                      ($name ? " from user $name" : '') .
                      ": @links" );
        return;
    }
    else
    {
        $self->respond( $message, "No urls found" .
                      ($name ? " from user $name" : '') );
        return;
    }
}


sub pipsqueek_mergeuser
{
    my ($self,$message,$user1,$user2) = @_;

    my $sql = 'UPDATE linkgrabber SET userid=? WHERE userid=?';
    my $sth = $self->dbi()->dbh()->prepare( $sql );
       $sth->execute( $user1->{'id'}, $user2->{'id'} );
}


1;


__END__

