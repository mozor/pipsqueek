package PipSqueek::Plugins::Math;
use base qw(PipSqueek::Plugin);

use Parse::RecDescent;

our $result; # WARN: Multiple instances of this module will fuck up
our $parser; # ^^^^

$::RD_HINT = 1;

my $grammar = <<'_EOGRAMMAR_';

start:  statement  /^\Z/  { $PipSqueek::Plugins::Math::result = $item[1] == 0 ? "0e0" : $item[1]; }


statement:  precedence_1


precedence_1:   <leftop: precedence_2 ('+' | '-') precedence_2> { PipSqueek::Plugins::Math::leftop(@item) }


precedence_2:   <leftop: precedence_3 ('*' | '/' | '%') precedence_3> { PipSqueek::Plugins::Math::leftop(@item) }


precedence_3:   precedence_4 
		| '+' precedence_4  {$item[2]}
		| '-' precedence_4  {$item[2]*-1}


precedence_4:   <rightop: precedence_5 ('^') precedence_5> { PipSqueek::Plugins::Math::rightop(@item) }


precedence_5:   '(' statement ')'  {$item[2]}
		| number


number:         /(?=\d|\.\d)\d*(\.\d*)?([Ee](\d+))?/  {$item [1]}
                | '_'  { $PipSqueek::Plugins::Math::result }
		| 'pi' { 3.1415926535897932 }

_EOGRAMMAR_

sub leftop
{
	my $orig = shift @{$_[1]};
	while( @{$_[1]} )
	{
		my ($op,$v) = splice(@{$_[1]}, 0, 2);
		   if( $op eq '+' ) { $orig+=$v }
		elsif( $op eq '-' ) { $orig-=$v }
		elsif( $op eq '%' ) { $orig%=$v }
		elsif( $op eq '/' ) { $orig/=$v }
		elsif( $op eq '*' ) { $orig*=$v }
	}
	return $orig;
}

sub rightop
{
	@_ = @{$_[1]};
	while ( @_ > 1 )
	{
		my ($y,$op,$x) = (pop(@_),pop(@_),pop(@_));
		if( $op eq '^' ) { push(@_, $x ** $y) }
	}
	return $_[0];
}



sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers(
		'multi_math'  => 'handle_math',
	);
	
	$parser = Parse::RecDescent->new( $grammar ) or die "Bad Grammar!\n";
}

sub plugin_teardown { }

sub handle_math
{
	my ($self,$message) = @_;
	my ($expr) = $message->message() =~ m/math (.+)$/;

	my $Heap = $self->kernel()->get_active_session()->get_heap();
	$result = $Heap->{'last_math_result'};

	unless( defined($expr) )
	{
		return $self->respond( $message, 
			"Usage: math <expression>" );
	}

	my $original = $result;

	if( $parser->start($expr) )
	{
		$Heap->{'last_math_result'} = $result;
		$expr =~ s/_/$original/g;
		if( $result eq '0e0' ) { $result = 0 }

		return $self->respond( $message, 
			$message->nick() . ": $result" );
	}
	else
	{
		return $self->respond( $message, 
			"Invalid input in expression" );
	}
}


1;


