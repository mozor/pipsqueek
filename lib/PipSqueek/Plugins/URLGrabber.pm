package PipSqueek::Plugins::URLGrabber;
use base qw(PipSqueek::Plugin);

use Data::Dumper;
use File::Spec::Functions;
use URI::Find::Schemeless;

my $URLS;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'irc_public',
		'multi_urls',
	]);


	my $file = catfile( $self->cwd(), '/var/urlgrabber.dat' );
	if( -e $file )
	{
		open( my $fh, '<', $file ) or warn "Error opening '$file': $!";
		return unless $fh;
		my @lines = <$fh>;
		close( $fh );

		chomp(@lines);
		my $input = join('',@lines);

		
		my $data; eval "$input";
		@$URLS = @$data;
	}
}

sub plugin_teardown 
{ 
	my $self = shift;
	my $file = catfile( $self->cwd(), '/var/urlgrabber.dat' );

	my $dumper = Data::Dumper->new( [$URLS], [ 'data' ] );
		$dumper->Indent(0);

	open( my $fh, '>', $file ) or warn "Error writing '$file': $!";
	return unless $fh;
	print $fh $dumper->Dump();
	close( $fh );
}

sub irc_public
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);
	my $text = $message->message();

	my $finder = URI::Find::Schemeless->new( sub { $self->add_url( $user, @_ ) } );
	my $count = $finder->find( \$text );

	return;
}

sub add_url
{
	my ($self,$user,$uri,$orig_uri) = @_;
	my $url = $uri->as_string();
	push( @{$URLS}, {
		'url' => $url,
		'time' => time(),
		'user' => $user->{'username'} 
	} );
}

sub multi_urls
{
	my ($self,$message,@args) = @_;
	my ($username,$maximum) = (undef,3);

	if( @args >= 2 )
	{
		$username = $args[1];

		if( $args[0] && $args[0] !~ /[^0-9]/ )
		{
			$maximum = $args[0];
		}
	}
	elsif( @args == 1 )
	{
		if( $args[0] =~ /[^0-9]/ )
		{
			$username = $args[0];
		}
		else
		{
			$maximum = $args[0] || 3;
		}
	}

	if( $username )
	{
		if ( my $user = $self->find_user($username) )
		{
			$username = $user->{'username'};
		}
		else
		{
			return $self->respond( $message, "That user does not exist" );
		}
	}

	$maximum = 5 if $maximum > 5;

	my @found_urls;
	foreach my $url (reverse @{$URLS})
	{
		if( $username )
		{
			next unless $url->{'user'} eq $username;
		}

		push(@found_urls,$url);

		last if( @found_urls == $maximum );
	}

	if( @found_urls )
	{
		local $" = ' - ';
		my @f = map { $_->{'url'} } @found_urls;

		return $self->respond( $message, 
			"Last $maximum URLS" . 
			($username ? " from user $username" : '') .
			": @f" );
	}
	else
	{
		return $self->respond( $message, 
			"No urls found" .
			($username ? " from user $username" : '') );
	}
}


1;


