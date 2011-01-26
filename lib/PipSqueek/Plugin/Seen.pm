package PipSqueek::Plugin::Seen;
use base qw(PipSqueek::Plugin);
use strict;
use integer;

sub plugin_initialize {
  my $self = shift;

  $self->plugin_handlers([
    'multi_seen',
    'multi_active',
    'irc_public'
  ]);

  my $schema = [
    ['id', 'INTEGER PRIMARY KEY'], # This is a user_id
    ['last_seen_really', 'TIMESTAMP'],
    ['last_seen_really_data', 'VARCHAR'],
  ];

  $self->dbi()->install_schema('seen', $schema);
}


sub multi_seen
{
    my ($self,$message) = @_;
    my $username = $message->command_input();

    $username =~ s/\s+$//;

    unless( defined($username) )
    {
        $self->respond( $message, "Use !help seen" );
        return;
    }

    if( lc($username) eq lc($self->config()->current_nickname()) )
    {
        $self->respond( $message, "You found me!" );
        return;
    }

    my $user = $self->search_user( $username );

    unless( $user )
    {
        $self->respond( $message,
            "Sorry, I don't seem to know that user." );
        return;
    }


    my $sender = $self->search_or_create_user( $message );

    if( lc($username) eq lc($sender->{'username'})
     || lc($username) eq lc($sender->{'nickname'}) )
    {
        $self->respond( $message, "Peekaboo! I found you!" );
        return;
    }


    unless( $user->{'last_seen'} )
    {
        $self->respond( $message, "When I know, you'll know." );

        return;
    }

    my $elapsed = $self->format_elapsed_time($user->{'last_seen'}, time());

    $self->respond( $message, 
        "I saw $username $elapsed ago, $user->{'seen_data'}" );

    return 1;
}


sub multi_active {
  my ($self, $message) = @_;
  my $username = $message->command_input();

  $username =~ s/\s+$//;

  unless(defined($username)) {
    $self->respond($message, "Use !help active");
    return;
  }

  if(lc($username) eq lc($self->config()->current_nickname())) {
    $self->respond($message, "You found me!");
    return;
  }

  my $user = $self->search_user($username);

  unless($user) {
    $self->respond($message, "Sorry, I don't seem to know that user.");
    return;
  }


  my $sender = $self->search_or_create_user($message);

  if(lc($username) eq lc($sender->{'username'})
  || lc($username) eq lc($sender->{'nickname'})) {
    $self->respond($message, "Peekaboo! I found you!");
    return;
  }

  my $row = $self->dbi()->select_record(
    'seen',
    { 'id' => $user->{id} }
  );

  unless($row->{'last_seen_really'}) {
    $self->respond($message, "When I know, you'll know.");

    return;
  }

  my $elapsed = $self->format_elapsed_time($row->{'last_seen_really'}, time());

  $self->respond($message, "I saw $username $elapsed ago, $row->{'last_seen_really_data'}");

  return 1;
}


sub irc_public {
  my ($self, $message) = @_;
  my $msg = $message->message();

  my $user = $self->search_user($message->nick());

  my $row = $self->dbi()->select_record(
    'seen',
    {
      'id' => $user->{id},
    }
  );

  if($row) {
    $self->dbi()->update_record(
      'seen',
      {
        'id' => $user->{id},
        'last_seen_really' => time(),
        'last_seen_really_data' => $msg
      }
    );
  } else {
    $self->dbi()->create_record(
      'seen',
      {
        'id' => $user->{id},
        'last_seen_really' => time(),
        'last_seen_really_data' => $msg
      }
    );
  }
}


sub format_elapsed_time
{
    my ($self,$start,$end) = @_;

    my $ela = $end - $start;
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

    return $output;
}


1;


__END__
