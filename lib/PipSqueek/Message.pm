package PipSqueek::Message;
use base 'Class::Accessor::Fast';
use strict;

sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = bless( {}, $class );

	$self->mk_accessors(
		qw( sender nick ident host recipients
		    channel message raw event
		    is_command command command_input
		    _config )
	);

	my $config = shift;

	unless( defined($config) && ref($config) =~ /^PipSqueek::Config/ )
	{
		die "Must pass a PipSqueek::Config to Message->new()\n";
	}

	$self->_config( $config );
	$self->parse(@_);

	return $self;
}


# Attempts to put english names to the arguments sent to standard PoCo::IRC 
# event handlers.  If you're writing a handler for pipsqueek for a specific 
# irc_bleh event, check what arguments are sent to it by printing out
# $self->parse(@_)->raw, then - if the arguments to that event would fit in 
# this parser (where it says 'custom mode parsing') please add the code and 
# email a diff file, otherwise just write the parsing yourself in your module 
sub parse
{
	my ($self,$event,@args) = (@_);

	$self->raw(\@args);
	$self->event($event);

	if( $event eq 'irc_error' || $event eq 'irc_socketerr' )
	{
		$self->message($args[0]);
		return $self;
	}

	# save the sender info
	$self->sender($args[0]);

	# parse a nick!ident@hostmask sender into appropriate fields
	if( $args[0] =~ /^(.*?)!(.*?)\@(.*?)$/ )
	{
		$self->nick($1);
		$self->ident($2);
		$self->host($3);
	}

	my @recipients;
	# more than one argument sent?
	if( defined($args[1]) )
	{
		if( ref($args[1]) eq 'ARRAY' )
		{
			if( $args[1]->[0] =~ /^[#&+!]/  )
			{
				$self->channel($args[1]->[0]);
			}

			foreach my $arg ( @{$args[1]} )
			{
				push( @recipients, $arg );
			}
		}
		else
		{
			# customized mode parsing

			# The above will catch most argument lists,
			# but there are quite a few (especially the irc_XXX
			# numeric events) that have arguments that require
			# special parsing
			
			if( $event eq 'irc_mode' )
			{
				if( $args[1] =~ /^[#&+!]/ ) 
				{
					$self->channel($args[1]);
				}
				else 
				{
					$self->nick($args[1]); 
				}

				if( defined($args[3]) && $args[3] ne "" )
				{
					$self->recipients([@args[3..$#args]]);
				}
				else
				{
					$self->recipients([$args[1]]);
				}
			}
			elsif( $event eq 'irc_353' ) 
			# list of names upon entering a channel
			{
				my ($channel,$names) = split(/:/, $args[1]);
				$channel =~ s/^.*[#&+!]/#/g;
				$channel =~ s/ +$//g;

				$self->channel($channel);
				$self->recipients( [ split(/ /,$names) ] );
			}
			elsif( $event eq 'irc_kick' )
			{
				$self->channel($args[1]);
				push( @recipients, $args[2] );
				$self->message($args[3]);
			}
			elsif( $event eq 'irc_join' || $event eq 'irc_part' )
			{
				my ($channel,$msg) = $args[1] =~ 
					m/^([#&+!].*?)(?: :(.*))?$/;
				$self->channel($channel);
				$self->message($msg);
			}
			elsif( $event eq 'irc_332' )
			# topic when joining the channel (or reply to /topic)
			{
				my ($channel,$msg) = $args[1] =~
					m/^([#&+!].*?)(?: :(.*))?$/;
				$self->channel($channel);
				$self->message($msg);
			}
			elsif( $event eq 'irc_333' )
			{
				my ($chan,$name,$time) = split(/\s+/,$args[1]);
				$self->channel($chan);
				$self->nick($name);
				$self->message($time);
			}
			elsif( $event eq 'irc_topic' )
			{
				$self->channel($args[1]);
			}
			else
			{
				$self->message($args[1]);
			}
		}
	}

	if( @recipients ) 
	{
		$self->recipients(@recipients);
	}

	# If we still have another argument, it's the event's message
	if( defined($args[2]) && !defined($self->message()) )
	{ 
		$self->message($args[2]);
	}


	# is this message a command? 
	my $prefixed = $self->_config()->public_command_prefix();
	my $nickname = $self->_config()->current_nickname();
	my $c_answer = $self->_config()->answer_when_addressed();

	my $command = undef;
	my $c_input = undef;
	my $input = $self->message();

	# !quote
	if( $prefixed && $input =~ /^$prefixed/i )
	{
		$input =~ s/^$prefixed//i;

		($command,$c_input) = $input =~ m/^(.*?)(?:\s+(.*))?$/;
	}
	# PipSqueek: !quote, PipSqueek: quote, or PipSqueek, quote
	elsif( $c_answer && $input =~ /^$nickname[:,]/ )
	{
		$input =~ s/^$nickname[:,]\s*//i;

		($command,$c_input) = $input =~ m/^(.*?)(?:\s+(.*))?$/;

		$command =~ s/^$prefixed//;
	}
	# quote (privmsg only)
	elsif( $self->event() eq 'irc_msg' )
	{
		($command,$c_input) = $input =~ m/^(.*?)(?:\s+(.*))?$/;
	}
	elsif( $self->event() =~ m/^private_/ )
	{
		($command,$c_input) = $input =~ m/^(.*?)(?:\s+(.*))?$/
	}


	if( $command ) 
	{
		$self->is_command($command);
		$self->command($command);
		$self->command_input($c_input);
	}

	return 1;
}


sub debug
{
	my ($message) = @_;

	my $format = "% 10s:\t%s\n";

	print "\n";

	my @fields = qw( sender nick ident host recipients channel message 
			 raw event is_command command command_input );

	foreach my $field (@fields)
	{
		if( $field eq 'raw' ) 
		{
			printf( $format, $field );

			foreach my $a (@{$message->raw()}) 
			{
				if ( ref($a) eq 'ARRAY' ) 
				{
					local $" = ", ";
					printf( $format, "", "[@$a]" );
				} 
				else 
				{
					next unless $a ne "";
					printf( $format, "", $a );
				}
			}
		}
		else 
		{
			printf( $format, $field, $message->$field() );
		}
	}

	print "\n";
}		



1;

__END__

