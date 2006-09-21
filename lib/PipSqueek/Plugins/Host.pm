package PipSqueek::Plugins::Host;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_host',
	]);
}

sub plugin_teardown { }

sub multi_host
{
	my ($self,$message) = @_;
	my ($input) = $message->message() =~ m/host\s+(.+?)$/;

	if( $input =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ )
	{
		my ($name) = gethostbyaddr( pack("C4",split(/\./,$input)), 2);

		if( $name )
		{
			return $self->respond( $message, "$input => $name" );
		}
		else
		{
			return $self->respond( $message, "No hostname found for $input" );
		}
	}
	elsif( $input =~ /^[[:alnum:]-]+(?:\.[[:alnum:]-]+)*\.[[:alpha:]]+$/ )
	{
		my ($name,$aliases,$type,$length,@addresses) =
			gethostbyname($input);

		if( @addresses )
		{
			my $output = "$input has address" . (@addresses > 1 ? 'es' : '') . ' ';
			  $output .= join(', ', map { join('.',unpack("C4",$_)) } @addresses );
			return $self->respond( $message, $output );
		}
		else
		{
			return $self->respond( $message, "Record not found" );
		}
	}
	else
	{
		return $self->respond( $message, "Invalid input" );
	}
}


1;


