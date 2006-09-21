package PipSqueek::Plugin::NumberConversion;
use base qw(PipSqueek::Plugin);
use strict;


sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers({
		'multi_int2hex' => 'convert',
		'multi_int2bin' => 'convert',
		'multi_int2oct' => 'convert',
		'multi_hex2int' => 'convert',
		'multi_hex2bin' => 'convert',
		'multi_hex2oct' => 'convert',
		'multi_oct2int' => 'convert', 
		'multi_oct2bin' => 'convert', 
		'multi_oct2hex' => 'convert',
	});
}


sub convert
{
	my ($self,$message) = @_;
	my $event = $message->event();
	my $input = $message->command_input();

	unless( defined($input) && $input ne "" )
	{
		$self->respond( $message, "Invalid input, use !help" );
		return;
	}

	if( $input eq '_' )
	{
		$input = $self->client()->get_heap()->{'last_math_result'};
	}

	$event =~ s/^(public|multi|private)_//;

	my $result = $self->$event( $input );

	$self->respond_user( $message, "$result" );
		
	$self->client()->get_heap()->{'last_math_result'} = $result;

	return;
}


sub bin2int
{
	my ($self,$in) = @_;
	return unpack("N", pack("B32", substr("0" x 32 . $in, -32)));
}

sub bin2hex
{
	my ($self,$in) = @_;
	return unpack("H8", pack("B32", substr("0" x 32 . $in, -32)));
}

sub bin2oct
{
	my ($self,$in) = @_;
	return sprintf "%o", 
		unpack("N", pack("B32", substr("0" x 32 . $in, -32)));
}

sub int2bin
{
	my ($self,$in) = @_;
	my $out = unpack("B*", pack("N", $in));
	$out =~ s/^0+//g;
	return $out;
}

sub int2hex
{
	my ($self,$in) = @_;
	my $out = unpack("H8", pack("N", $in));
 	return sprintf '%x', $in;
}

sub int2oct
{
	my ($self,$in) = @_;
	return sprintf "%o", $in;
}

sub hex2bin
{
	my ($self,$in) = @_;
	my $out = unpack("B32", pack("N", hex $in));
	$out =~ s/^0+//g;
	return $out;
}

sub hex2int
{
	my ($self,$in) = @_;
	return hex $in;
}

sub hex2oct
{
	my ($self,$in) = @_;
	return sprintf "%o", hex $in;
}

sub oct2bin
{
	my ($self,$in) = @_;
	my $out = unpack("B32", pack("N", oct $in));
	   $out =~ s/^0+//g;
	return $out;
}

sub oct2int
{
	my ($self,$in) = @_;
	return oct $in;
}

sub oct2hex
{
	my ($self,$in) = @_;
	return unpack("H8", pack("N", oct $in));
}


1;


__END__
