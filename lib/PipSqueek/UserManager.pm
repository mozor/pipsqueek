package PipSqueek::UserManager;

use strict;
use warnings;

use XML::Simple;
#use Data::Dumper;


# General Application Routines:
sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	
	my $self = {};
	my $args = shift;
	
	$self->{'file'} = $args->{'file'};
	# the file we load our user database from

	bless($self,$class);

	$self->load();

	return $self;
}


sub load
# loads our user database from an XML file and stores them 
{
	my $self = shift;

	if( -e $self->{'file'} )
	{
		$self->{'users'} = XMLin( $self->{'file'}, forcearray => ['user'] )->{'user'}
		or die "Could not load users from file '" . $self->{'file'} . "': $!\n";

		foreach my $x ( 0 .. $#{$self->{'users'}} )
		{ # build our name2id hash
			$self->{'name2id'}->{ lc( $self->{'users'}->[$x]->{'nick'} ) } = $x;
		}
	}
	else
	{
		$self->{'users'} = ();
		$self->{'name2id'} = {};
#		warn "'" . $self->{'file'} . "' not found.";
	}

	return 1;
}


sub save
# saves our user database into the XML file
{
	my $self = shift;
	my $hash = {};

	if( defined( $self->{'users'}->[0] ) )
	{
		$hash->{'user'} = $self->{'users'};
		# we construct the temporary hash here so that the XML output is more human-readable
		XMLout( $hash, outputfile => $self->{'file'} ) 
		or die "Could not save users to file '" . $self->{'file'} . "': $!\n";
		# TODO: Some sort of file locking? #
	}

	return 1;
}


sub user
# returns a hash of user information, or undef if the user was not found
{
	my $self = shift;
	my $nick = shift || return -1;
	my $uid = $self->uid($nick);
	return undef if $uid == -1;

	my $user = $self->{'users'}->[$uid];
	$user->{'uid'} = $uid;
	# store their uid in the hash in case a handler wants that info

	return $user;
}

sub get_all_users
# returns a copy of our user hash
{
	my $self = shift;
	my @users = @{$self->{'users'}};
	return \@users;
}


sub param
# a modified version of the param() method in Bot.pm 
# a general accessor/mutator for the user hash
# you must send this one a nickname, followed by the key/value pairs
# or the key to retrieve
{

	my $self = shift;
	my $nick = shift;
	my $uid = $self->uid($nick);

	return undef if $uid == -1;

	my (@data) = (@_);

	my $params = $self->{'users'}->[$uid];

	if (scalar(@data)) 
	{ # If data is provided, set it!
		if ( ref($data[0]) eq 'HASH' ) 
		{ # Is it a hash, or hash-ref?
			%$params = (%$params, %{$data[0]});
			# Make a copy, which augments the existing contents (if any)
		}
		elsif ((scalar(@data) % 2) == 0) 
		{ # It appears to be a possible hash (even number of elements)
			%$params = (%$params, @data);
		}
		elsif (scalar(@data) > 1) {
			die "Odd number of elements passed to param().";
		}
	} else {
		return (keys(%$params));
	}

	if (scalar(@data) <= 2) 
	{ # If exactly one parameter was sent to param(), return the value
		my $param = $data[0];
		return $params->{$param};
	}

	return; # Otherwise, return undef 
}


sub param_all
# just calls param() with each of the nicknames we store
{
	my $self = shift;
	my @data = @_;
	
	foreach my $x ( 0 .. $#{$self->{'users'}} )
	{
		$self->param( $self->{'users'}->[$x]->{'nick'}, @data );
	}

	return 1;
}


sub adduser
# adds a new user to the bot database
{
	my $self = shift;
	my $nick = shift || die "A nickname must be passed to adduser";
	push( @{$self->{'users'}},
		{
			'nick' => $nick,
			'original' => $nick,
			'chars' => 0,
			'words' => 0,
			'lines' => 0,
			'actions' => 0,
			'smiles' => 0,
			'modes' => 0,
			'topics' => 0,
			'kicks' => 0,
			'kicked' => 0,
			'seen' => 0,
			'active' => 1,
			'host' => ""
		}
	);
	$self->{'name2id'}->{lc($nick)} = $#{$self->{'users'}};
}


sub nick_change
# A convenience function to enable the bot to (sort of) track which users
# are linked to what data.  The hash stores a 'nick' and an 'original'
# field, the 'original' field holds what nickname they !addme'd on, the
# 'nick' field holds their current nickname.  The name2id hash is updated
# to reflect the new change, as well as the user hash
{
	my $self = shift;
	my ($old,$new) = @_;
	my $uid = $self->uid($old);
	return 0 if $uid == -1;

	$self->param($old,
		{'seen' => time(), 'active' => 0}
	);
	# the old user was last seen now, they're no longer active
	
	my $nuid = $self->uid($new);
	if( $nuid >= 0 ) {
		$self->{'name2id'}->{lc($new)} = $nuid;
		$self->param($new, 
			{'seen' => time(), 'active' => 1}
		);
	} else {
		$self->{'name2id'}->{lc($new)} = $uid;
		$self->param($new, 
			{'nick' => $new, 'seen' => time(), 'active' => 1}
		);
	}
}


# Internal methods

sub uid
# returns the userid for a particular nickname, or -1 if not found
{
	my $self = shift;
	my $nick = shift || return -1;
	
	my $uid = $self->{'name2id'}->{ lc($nick) };
	$uid = -1 unless defined($uid);
	$uid = -1 if $uid eq "";

	if( $uid == -1 ) {
		foreach my $x ( 0 .. $#{$self->{'users'}} ) {
			if( lc($self->{'users'}->[$x]->{'original'}) eq lc($nick) ) {
				$uid = $x; 
				last;
			}
		}
	}

	return $uid;
}


1; # module loaded successfully

