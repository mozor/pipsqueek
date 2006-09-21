package PipSqueek::Plugin::Logging;
use base 'PipSqueek::Plugin';

use File::Path;
use File::Spec::Functions qw(catdir catfile);


sub config_initialize
{
	my $self = shift;

	$self->plugin_configuration({
		'logging' => 1,
	});
}


sub plugin_initialize
{
	my $self = shift;
	my $conf = $self->config();

	if( $conf->logging() )
	{
		$self->plugin_handlers([
			'irc_001',	# for setting up the log file
			'irc_public',	# for logging channel text
			'irc_ctcp_action', # for logging channel actions
			'irc_mode',	# for logging mode changes
			'irc_nick',	#  " nick changes
			'irc_join',	#  " users joining
			'irc_part',	#  " users leaving
			'irc_quit',	#  " users disconnecting
			'irc_topic',	#  " when users change topic
			'irc_332',	# the topic of the channel when we join
			'irc_333',	# info about who set the topic
			'sentmsg',	# this gets posted when _we_send_ a
					# message to the server
			'sentact',	# same but when we perform a /me
		]);

		my $path = catdir( $self->client()->BASEPATH(), 'var/logs' );

		unless( -d $path )
		{
			eval { mkpath( $path) };

			if( $@ ) {
				die "Couldn't make path: $path\n";
			}
		}

		my $server  = $self->config()->server_address();
		my $channel = $self->config()->server_channel();

		my $file = catfile( $path, "$server-$channel.log" );

		open( $self->{'LOG'}, '>>', $file ) 
			or warn "Unable to open log '$file': $!\n";
		$self->{'LOG'}->autoflush(1);# TODO: this isn't cricket
	}
}


sub plugin_teardown
{
	my $self = shift;

	if( $self->{'LOG'} )
	{
		close( $self->{'LOG'} );
	}
}


sub irc_001
{
	my ($self,$message) = @_;

	my $server = $message->sender();

	$self->log( "*** Connected to $server ***" );
}


sub irc_public
{
	my ($self,$message) = @_;

	my $nick = $message->nick();
	my $text = $message->message();

	$self->log( "<$nick> $text" );
}


sub irc_ctcp_action
{
	my ($self,$message) = @_;

	my $nick = $message->nick();
	my $text = $message->message();

	$self->log( "* $nick $text" );
}


sub irc_topic
{
	my ($self,$message) = @_;

	my $nick = $message->nick();
	my $topic = $message->message();

	$self->log( "--- $nick has changed the topic to: $topic" );
}


sub irc_332
{
	my ($self,$message) = @_;

	my $topic = $message->message();
	my $channel = $message->channel();

	$self->log( "--- Topic for $channel is $topic" );
}


sub irc_333
{
	my ($self,$message) = @_;

	my $nick  = $message->nick();
	my $time  = $message->message();
	my $channel = $message->channel();

	$self->log( "--- Topic for $channel set by $nick at $time" );
}


sub irc_mode
{
	my ($self,$message) = @_;

	my $nick = $message->nick();
	my $mode = $message->message();
	   $mode =~ s/^://;
	my $rest = join(' ', @{$message->recipients()});

	$self->log( "--- $nick sets mode $mode $rest" );
}


sub irc_part
{
	my ($self,$message) = @_;
	
	my $nick = $message->nick();
	my $sender = $message->sender();
	   $sender =~ s/^.*?!//;
	my $channel = $message->channel();

	$self->log( "<-- $nick ($sender) has left $channel" );
}


sub irc_join
{
	my ($self,$message) = @_;

	my $nick = $message->nick();
	my $sender = $message->sender();
	   $sender =~ s/^.*?!//;
	my $channel = $message->channel();

	$self->log( "--> $nick ($sender) has joined $channel" );
}


sub irc_quit
{
	my ($self,$message) = @_;

	my $nick = $message->nick();
	my $text = $message->message();

	$self->log( "<-- $nick has quit ($text)" );
}


sub irc_nick
{
	my ($self,$message) = @_;

	my $old_user = $message->nick();
	my $new_user = $message->message();

	$self->log( "--- $old_user is now known as $new_user" );
}


sub sentmsg
{
	my ($self,$message) = @_;

	my $nick = $message->sender();
	my $text = $message->message();

	if( $message->channel() )
	{
		$self->log( "<$nick> $text" );
	}
}

sub sentact
{
	my ($self,$message) = @_;

	my $nick = $message->sender();
	my $text = $message->message();

	if( $message->channel() )
	{
		$self->log( "* $nick $text" );
	}
}


sub log
{
	my ($self,$text) = @_;

	my $LOG = $self->{'LOG'};

	if( $LOG )
	{
		print $LOG time(), ": $text\n";
#		print      time(), ":\t$text\n";
	}
}


1;


__END__
