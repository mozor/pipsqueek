package Interface::Param;
#use strict; # disabled in release code

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(param);
@EXPORT_OK = qw(param);

sub param 
{
	my $self = shift;
	my $data = $self->{'_params'} ||= {};
	# Initialize empty params hash if this is our first time

	if( @_ > 1 )
	# Accept data as (key, value, key1, value1)
	{
		die "Element list must be even" unless @_ % 2 == 0;
		%$data = (%$data, @_);
	}
	elsif( @_ == 1 )
	{
		if( ref $_[0] eq 'HASH' ) 
		# Maybe they want us to set a HASHREF
		{
			%$data = (%$data,%{$_[0]});
		}
		else
		# They want us to give them the value for a key
		{
			return $data->{$_[0]};
		}
	}
	else
	# Called with no args, return list of param keys
	{
		return keys %$data;
	}
}


1;


