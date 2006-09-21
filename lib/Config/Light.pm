package Config::Light;
#use strict; # disabled in release code

use Interface::Param qw(param);

sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = bless( {}, $class );

	if( my $file = shift )
	{
		$self->load( $file );
	}

	return $self;
}

sub load
{
	my ($self,$file) = @_;
	die "No file to load!" unless $file;
	die "Unable to read $file!" unless -r $file;

	open( INF, $file ) or die "Unable to open $file: $!";
	my @lines = <INF>; chomp(@lines);
	close( INF );

	my @blocks = ();
	foreach my $line ( grep {!/^\s*#/} @lines )
	{
		next unless $line =~ /[^\s]/;
		# skip blank lines

		if( $line =~ /^\s*<([^\/].*?)>\s*$/ )
		# grab block <foo>
		{
			push(@blocks,$1); next;
		}

		if( $line =~ /^\s*<\/(.*?)>\s*$/ )
		# end block </foo>
		{
			# TODO: Check for valid closing tag
			pop(@blocks); next;
		}
		

		my ($k,$v) = $line =~ /^\s*(.+?)\s*[=:\t]\s*(.+?)\s*;?\s*$/;
		# parse out a simple key=value

		$k =~ s/^\s*|\s*$//g;
		# trim whitespace on key

		if( $v =~ /^\s*["'](.*?)['"]\s*;?$/ )
		# grab everything in between the outermost quotes
		{
			$v = $1;
		} 
		else
		# doesn't have quoted data
		{
			$v =~ s/^\s*|\s*$//g;
			# trim whitespace on value
		}

		if( @blocks >= 1 )
		# we're nested 
		{
			my $c = $self->param($blocks[0]) || {};
			# get original tree
			my $l = $c;

			foreach my $x ( 1 .. $#blocks )
			# recurse for all blocks nested below the root
			{
				$l = $l->{$blocks[$x]} ||= {};
				# move down a level
			}
			
			$l->{$k} = $v;
			# store the value

			$self->param( $blocks[0] => $c );
			# save entire tree back
		}
		else
		# no block, stick it in the top level
		{
			$self->param( $k => $v );
		}
	}
	
	return;
}


1;


