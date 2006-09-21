package PipSqueek::Plugin::Math;
use base qw(PipSqueek::Plugin);

use Parse::RecDescent;

our $parser;

$::RD_HINT = 1;

our $grammar = <<'_EOGRAMMAR_';

start:  statement  /^\Z/  { $item[1] == 0 ? "0e0" : $item[1]; }


statement:  precedence_1


precedence_1:   <leftop: precedence_2 ('+' | '-') precedence_2> { PipSqueek::Plugin::Math::leftop(@item) }


precedence_2:   <leftop: precedence_3 ('*' | '/' | '%') precedence_3> { PipSqueek::Plugin::Math::leftop(@item) }


precedence_3:   precedence_4 
		| '+' precedence_4  {$item[2]}
		| '-' precedence_4  {$item[2]*-1}


precedence_4:   <rightop: precedence_5 ('^') precedence_5> { PipSqueek::Plugin::Math::rightop(@item) }


precedence_5:   '(' statement ')'  {$item[2]}
		| number


number:         /(?=\d|\.\d)\d*(\.\d*)?([Ee](\d+))?/  {$item [1]}
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


sub op_count
{
    my $self = shift;
    my $tx = shift;
    my $oc = 0;

    print "op_count: $tx";

    while( $tx =~ s/\(([^\(\)]+?)\)// )
    {
        my $ix = $1;

        print "\tix: $ix";

        if( $ix =~ /\(.+\)/ ) {
            $oc += $self->op_count($ix);
        } else {
            $oc++;
        }
    }

    return $oc;
}



sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'multi_math'
	]);
	
	$parser = Parse::RecDescent->new( $grammar ) or die "Bad Grammar!\n";
}


sub multi_math
{
	my ($self,$message) = @_;
	
	my $session_heap = $self->client()->get_heap();
	my $result = $session_heap->{'last_math_result'};

	my $expr = $message->command_input();

	unless( defined($expr) )
	{
		$self->respond( $message, "Use !help math" );
		return;
	}

    my $par_cnt = $expr =~ tr/\(/\(/;
    my $ops_cnt = $self->op_count( $expr );

    if( $par_cnt > $ops_cnt ) {
        $self->respond( $message, "Yummy, parens!" );
        return;
    }

	my $original = $result;
	$expr =~ s/_/$result/g;

	if( $result = $parser->start($expr) )
	{
		$session_heap->{'last_math_result'} = $result;
		if( $result eq '0e0' ) { $result = 0 }

		return $self->respond_user( $message, $result );
	}
	else
	{
		return $self->respond( $message, 
			"Invalid input in expression" );
	}
}


1;


__END__
