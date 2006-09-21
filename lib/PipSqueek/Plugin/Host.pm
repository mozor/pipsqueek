package PipSqueek::Plugin::Host;
use base qw(PipSqueek::Plugin);


sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_host',
	]);
}


sub multi_host
{
	my ($self,$message) = @_;
	my $input = $message->command_input();

	$input =~ s/\s+$//;

	if( $input =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ )
	{
		my ($name) = gethostbyaddr( pack("C4",split(/\./,$input)), 2);

		if( $name )
		{
			$self->respond($message,"$input => $name");
			return;
		}
		else
		{
			$self->respond( $message, 
				"No hostname found for $input" );
			return;
		}
	}
	elsif( $input =~ /^[[:alnum:]-]+(?:\.[[:alnum:]-]+)*\.[[:alpha:]]+$/ )
	{
		my ($name,$aliases,$type,$length,@ips) =
			gethostbyname($input);

		if( @ips )
		{
			my $s = @ips == 1 ? '' : 'es';
			@ips = map { join( '.', unpack("C4",$_) ) } @ips;

			local $" = ", ";
			my $output = "$input has address$s: @ips";

			return $self->respond( $message, $output );
		}
		else
		{
			return $self->respond( $message, "Record not found" );
		}
	}
	
	return $self->respond( $message, "Use !help host" );
}


1;


__END__
