package PipSqueek::Plugins::Seen;
use base qw(PipSqueek::Plugin);
use strict;


use integer;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers([
		'irc_join',
		'irc_part',
		'irc_public',
		'irc_nick',
		'irc_quit',
		'irc_353',

		'multi_seen',
	]);
}

sub plugin_teardown { }

sub _seen_entry
{
	my ($self,$message,$text,$type) = @_;
	my $user = $self->find_user($message);

	my $entry = {
		'time' => time(),
		'type' => $type,
		'text' => $text,
	};

	if( unshift( @{$user->{'seen'}}, $entry ) > 3 )
	{
		pop( @{$user->{'seen'}} );
	}	
}

sub irc_join
{
	my ($self,$message) = @_;
	my $user = $self->find_user($message);

	my $text = $message->message();
	   $text =~ s/^.*?://;

	$self->_seen_entry( $message, $text, 'join' );
}

sub irc_part
{
	my ($self,$message) = @_;
	$self->_seen_entry( $message, $message->message(), 'part' );
}

sub irc_quit
{
	my ($self,$message) = @_;
	$self->_seen_entry( $message, $message->message(), 'quit' );
}

sub irc_public
{
	my ($self,$message) = @_;

	unless( $self->is_command($message) ) {
		$self->_seen_entry( $message, $message->message(), 'public' );
	}
}

sub irc_353
{
	my ($self,$message) = @_;
	#foreach my $name ( @{ $message->recipients() } )
	#{
		#$name =~ s/^.// if /^[\^\+\@\%]/;
		#if( my $user = $self->find_user($name) )
		#{
		#}
	#}
}

sub irc_nick
{
	my ($self,$message) = @_;
	my ($from,$to) = ($message->nick(), $message->message());
	$self->_seen_entry( $message, "$from $to", 'nick' );
}


sub multi_seen
{
	my ($self,$message) = @_;
	my ($username) = $message->message() =~ m/seen\s+(.+)/;

	unless( defined($username) )
	{
		return $self->respond( $message,
			"You think that's air you're breathing now...?" );
	}

	my $sender = $self->find_user($message);

	if( my $user = $self->find_user($username) )
	{
		if( lc($username) eq lc($sender->{'username'})
		 || lc($username) eq lc($sender->{'nickname'}) )
		{
			return $self->respond( $message,
				"Looking for yourself, eh?" );
		}

		$username = $user->{'username'};
		unless( exists $user->{'seen'} )
		{
			return $self->respond( $message, 
				"No really, who are you looking for?" );
		}

		my @seen = @{$user->{'seen'}};

		my $ela = time() - $seen[0]->{'time'};
		my $day = $ela / 86400; $ela %= 86400;
		my $yea = $day / 365;   $day %= 365;
		my $cen = $yea / 100;   $yea %= 100;
		my $mil = $cen / 10;    $cen %= 10;
		my $hou = $ela / 3600;  $ela %= 3600;
		my $min = $ela / 60;    $ela %= 60;
		my $sec = $ela;

		my $_p = sub {
			my ($w,$e1,$e2,$t) = @_;
			return $t != 1 ? "$w$e2" : "$w$e1";
		};

		my @list = ();
		push(@list, "$mil " . &$_p('milleni','um','a',  $mil) ) if $mil;
		push(@list, "$cen " . &$_p('centur', 'y', 'ies',$cen) ) if $cen;
		push(@list, "$yea " . &$_p('year',   '',  's',  $yea) ) if $yea;
		push(@list, "$day " . &$_p('day',    '',  's',  $day) ) if $day;
		push(@list, "$hou " . &$_p('hour',   '',  's',  $hou) ) if $hou;
		push(@list, "$min " . &$_p('minute', '',  's',  $min) ) if $min;
		push(@list, "and" ) if $min;
		push(@list, "$sec " . &$_p('second', '',  's',  $sec) ) if $sec;
		my $output = join(' ', @list );


		my $type = $seen[0]->{'type'};
		my $text = $seen[0]->{'text'};

		if( $type eq 'public' ) {
			$text = "saying: $text";
		}
		elsif( $type eq 'nick' ) {
			my ($from,$to) = split(/ /,$text);
			$text = "changing nicks from $from to $to";
		}
		elsif( $type eq 'join' ) {
			$text = "joining the channel";
		}
		elsif( $type eq 'part' ) {
			$text = "leaving the channel with message: $text";
		}
		elsif( $type eq 'quit' ) {
			$text = "quitting the server with message: $text";
		}

		return $self->respond($message,
			"I saw $username $output ago, $text" );
	}
	else
	{
		return $self->respond($message, "That user does not exist");
	}
}


1;


