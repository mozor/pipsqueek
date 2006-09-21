package PipSqueek::Plugin::StringFuncs;
use base qw(PipSqueek::Plugin);
use strict;


sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'irc_public',

		'multi_rot13',
		'multi_reverse',
		'multi_length',
		'multi_morse',
	]);
}


# a rotating queue of the last said message in the channel
sub irc_public 
{
	my ($self,$message) = @_;
	my $c = $self->config();

	$self->{'messages'} ||= [];

	unless( $message->is_command() || 
		$message->nick() eq $c->current_nickname() ||
		length($message->message()) <= 3 )
	{
		$self->{'messages'}->[1] = $self->{'messages'}->[0];
		$self->{'messages'}->[0] = $message->message();
	}
}


# rot13 is a common encryption from usenet
sub multi_rot13
{
	my ($self,$message) = @_;

	my $text = $self->_get_text($message);
	   $text =~ tr/A-Za-z/N-ZA-Mn-za-m/;

	$self->_respond( $message, $text );
}


# reverses a string of text 
sub multi_reverse
{
	my ($self,$message) = @_;
	
	my $text = $self->_get_text($message);
	   $text = reverse($text);

	$self->_respond($message, $text);
}


# converts a string to morse, or vice versa
sub multi_morse
{
	my ($self,$message) = @_;

	my %A2M = qw(
		A .-
		B -...
		C -.-.
		D -..
		E .
		F ..-.
		G --.
		H ....
		I ..
		J .---
		K -.-
		L .-..
		M --
		N -.
		O ---
		P .--.
		Q --.-
		R .-.
		S ...
		T -
		U ..-
		V ...-
		W .--
		X -..-
		Y -.--
		Z --..
		. .-.-.-
		, --..--
		/ -...-
		: ---...
		' .----.
		- -....-
		? ..--..
		! ..--.
		@ ...-.-
		+ .-.-.
		0 -----
		1 .----
		2 ..---
		3 ...--
		4 ....-
		5 .....
		6 -....
		7 --...
		8 ---..
		9 ----.
	);

	my %M2A = reverse %A2M;


	my $text = $self->_get_text($message);
	my $output = "";

	if( $text =~ /[^. -]/ )
	{
		my $sub = sub { exists $A2M{$_[0]} ? "$A2M{$_[0]} " : "" };
		$text =~ s/(\S)/&$sub(uc($1))/ge;
	}
	else
	{
		my $sub = sub { exists $M2A{$_[0]} ? "$M2A{$_[0]} " : "" };
		$text =~ s/([\.-]+)\s?/&$sub($1)/ge;
		$text =~ s/ (?! )//g;
		$text = lc($text);
	}

	$self->_respond( $message, $text );
}

# returns the number of characters
sub multi_length
{
	my ($self,$message) = @_;

	my $text = $self->_get_text($message);
	my $ccnt = length($text);

	$self->_respond($message, $text, $ccnt);
}



sub _get_text
{
	my ($self,$message) = @_;
	my $text = $message->command_input();

	if( !defined($text) || $text eq "" )
	{
		$text = $self->{'messages'}->[0];
	}
	elsif( $text eq '%' )
	{
		$text = $self->client()->get_heap()->{'last_string_result'};
	}

	return $text;
}

sub _respond
{
	my ($self,$message,$text,$output) = @_;

	$output ||= $text;

	if( $text )
	{
		my $heap = $self->client()->get_heap();
		$heap->{'last_string_result'} = $text;
		return $self->respond_user( $message, $output );
	}
}


1;


__END__
