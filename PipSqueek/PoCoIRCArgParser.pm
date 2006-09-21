package PipSqueek::PoCoIRCArgParser;

use strict;
use warnings;


# General Application Routines:
sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	
	my $self = {};
	
	bless($self,$class);

	return $self;
}


sub parse
# Attempts to put english names to the arguments sent to standard
# PoCo::IRC event handlers.  If you're writing a handler for pipsqueek
# for a specific irc_bleh event, check what arguments are sent to it
# by printing out $parser->param('args'), then - if the arguments to
# that event would fit in this parser (where it says 'custom mode parsing')
# please add the code and email a diff file, otherwise just write
# the parsing yourself in your module and ignore the parser's attempts
{
	my $self = shift;
	my $type = shift;
	my @args = @_;
	$self->param('type' => $type);
	$self->param('args' => \@args);
	$self->param({
		'sender' => undef,
		'nick' => undef,
		'ident' => undef,
		'host' => undef,
		'recipients' => undef,
		'channel' => undef,
		'message' => undef,
	});
	# clear old params from last parse

	my ($sender,$nick,$ident,$host,$recipients,$channel,$message);
	# Most of the basic handler types' arguments can be broken into these

	if( $type eq 'irc_error' || $type eq 'irc_socketerr' ) 
	{ # ARG0 is the message text (no other args) for these two
		@{$message} = split(/ /,$args[0]);
		$self->param( 'message' => $message );
		$self->param( 'msg' => $args[0] );
		return;
	}

	$sender = $args[0];
	if( $args[0] =~ /^(.*?)!(.*?)\@(.*?)$/ ) {
	# parse a nick!ident@hostmask sender into appropriate fields
		($nick,$ident,$host) = ($1,$2,$3);
	}

	if( defined($args[1]) )
	# more than one argument sent?
	{
		if( ref($args[1]) eq 'ARRAY' ) {		# sometimes we get multiple recipients
			foreach my $arg ( @{$args[1]} ) {	# for irc_ctcp_* events, etc..
				push( @{$recipients}, $arg );
			}
		}
		elsif( $args[1] =~ /^#/ && $type ne 'irc_474' )	# if the recipient was a channel
		{												# (irc_privmsg, irc_invite, etc)
			$channel = $args[1];				# set the channel
			push( @{$recipients}, $args[1] );	# set the recipients
		}
		else
		{
			# The above will catch most argument lists, but there are quite a few
			# (especially the irc_XXX numeric events) that have arguments that require
			# special formatting

			# custom mode parsing

			if( $type eq 'irc_mode' )	# this is caught if the mode is set on yourself
			{							# since the recipient is a channel otherwise
				push(@{$recipients},$args[1]);	# and caught by the elsif above
			}
			elsif( $type eq 'irc_353' )	# list of names upon entering a channel
			{
				my ($chn,$msg) = split(/:/, $args[1]);
				$chn =~ s/^.*#/#/g; $chn =~ s/ +$//g;
				$channel = $channel;	# the channel they joined
				@{$message} = split(/ /,$msg);
			}
			else
			{
				@{$message} = split(/ /,$args[1]);	# otherwise ARG1 was the message
			}
		}
	}

	if( defined($args[2]) && !defined($message) )
	{ # If we still have another argument to get at, and we haven't got a message already
		@{$message} = split(/ /,$args[2]);
	}

	# some pipsqueek specific things
	if( $type =~ /^admin_/ ) {
		shift @{$message};	# dump the password
		shift @{$message};	# dump the command
	} elsif( $type =~ /^public_/ || $type =~ /^private_/ ) {
		shift @{$message};	# dump the command
	} 

	$self->param({
		'sender' => $sender,
		'nick' => $nick,
		'ident' => $ident,
		'host' => $host,
		'recipients' => $recipients,
		'channel' => $channel,
		'message' => $message,
		'msg' => (defined($message) ? join(' ',@{$message}) : undef ),
	});

#	print qq(Parser came up with:\n);
#	print qq(sender:\t\t$sender\n) if defined $sender;
#	print qq(nick:\t\t$nick\n) if defined $nick;
#	print qq(ident:\t\t$ident\n) if defined $ident;
#	print qq(host:\t\t$host\n) if defined $host;
#	print qq(recipients:\t@$recipients\n) if defined $recipients;
#	print qq(channel:\t$channel\n) if defined $channel;
#	print qq(message:\t@$message\n) if defined $message;

	return 1;
}
	
=cut
	[PoCo::IRC arguments sent to handlers]
	
	irc_connected
		ARG0: server name
	
	irc_ctcp_*
		ARG0: nick!hostmask
		ARG1: channel/recipient names (array ref)
		ARG2: text of the ctcp message

	irc_ctcpreply_*
		see irc_ctcp_*

	irc_disconnected
		ARG0: server name

	irc_error
		ARG0: server's reason for error

	irc_join
		ARG0: nick!hostmask
		ARG1: channel name

	irc_invite
		ARG0: nick!hostmask
		ARG1: channel to join

	irc_kick
		ARG0: kicker's nick!hostmask
		ARG1: channel name
		ARG2: kickee
		ARG3: explanation

	irc_mode
		ARG0: nick!hostmask of person changing mode
		ARG1: channel it affects (or your nick)
		ARG2: mode string
		ARG3 .. $#_: operands to the mode string

	irc_msg
		ARG0: nick!hostmask of sender
		ARG1: recipients (array ref)
		ARG2: text of message

	irc_nick
		ARG0: nick!hostmask of changer
		ARG1: new nickname
	
	irc_notice
		ARG0: nick!hostmask of sender
		ARG1: recipients (array ref)
		ARG2: text of message

	irc_part
		ARG0: nick!hostmask
		ARG1: channel name
		(ARG2: reason?)

	irc_public
		ARG0: nick!hostmask
		ARG1: recipients (array ref)
		ARG2: text of message

	irc_quit
		ARG0: nick!hostmask
		ARG1: quit message

	irc_socketerr
		ARG0: vague or misleading reason for why it failed

	irc_XXX
		ARG0: name of server
		ARG1: text of message
=cut




sub param
# a general accessor/mutator for the data hash
# borrowed from CGI::Application
{
	my $self = shift;
	my (@data) = (@_);

	$self->{'_data'} = {} unless (exists($self->{'_data'}));
	# create the hash if it doesn't exist

	my $params = $self->{'_data'};

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


1; # module loaded successfully

