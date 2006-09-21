package PipSqueek::Message;
use base 'Class::Accessor::Fast';
use strict;

sub new
{
	my $proto = shift;
	my $self  = bless( {}, ref($proto) || $proto );

	$self->mk_accessors( keys %{$_[0]} );

	while ( my ($k,$v) = each %{$_[0]} )
	{
		$self->$k($v);
	}

	return $self;
}


1;


