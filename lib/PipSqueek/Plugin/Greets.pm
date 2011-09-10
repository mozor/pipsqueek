package PipSqueek::Plugin::Greets;
use base qw(PipSqueek::Plugin);

# This plugin is heavily based on the Greetings module by Ilya.
# I've made a few changes to the way things work, and generally
# written tidier code. It should be a lot easier to maintain.

sub config_initialize {
  my ($self) = @_;

  # Set this in minutes.
  my $time_to_remember = 30;

  # This value is much more useful in seconds.
  $self->plugin_configuration('time_to_remember' => $time_to_remember*60);

  # Set this to the level at which someone can delete any greeting.
  $self->plugin_configuration('delete_level' => 100);
}

sub plugin_initialize {
  my ($self) = @_;

  $self->plugin_handlers(
    'irc_join'     => 'greet',
    'multi_+greet' => 'add_greet',
    'multi_-greet' => 'delete_greet',
  );

  my $schema = [
    ['id', 'INTEGER PRIMARY KEY AUTOINCREMENT'],
    ['user', 'VARCHAR'],
    ['greet', 'VARCHAR'],
    ['channel', 'VARCHAR'],
    ['added_by', 'VARCHAR'],
    ['added_on', 'TIMESTAMP'],
    ['last_used', 'TIMESTAMP'],
  ];

  $self->dbi()->install_schema('greets', $schema);
}

sub greet {
  my ($self, $message) = @_;

  my $dbh = $self->dbi()->dbh();
  my $sth = $dbh->prepare("
    SELECT
      *
    FROM
      greets
    WHERE
      lower(user)=lower(?)
    AND
      lower(channel)=lower(?)
    AND
      (?-last_used>?
    OR
      last_used=0)
  ");

  $sth->execute($message->nick(), $message->channel(), time(), $self->config()->time_to_remember());

  my $greeting = '';
  while(my $greet = $sth->fetchrow_hashref()) {
    $greeting .= $greet->{greet}." (".$greet->{id}.")  ";
  }

  if($greeting ne '') {
    $self->client()->privmsg($message->channel(), $message->nick().": $greeting");

    $sth = $dbh->prepare("
      UPDATE
        greets
      SET
        last_used=?
      WHERE
        lower(user)=lower(?)
      AND
        lower(channel)=lower(?)
    ");

    $sth->execute(time(), $message->nick(), $message->channel());
  }
}


sub add_greet {
  my ($self, $message) = @_;

  my @args = split(/\s+/, $message->command_input());
  my $for_user = shift @args;
  my $for_chan = shift @args;

  if($for_user =~ m/^#/) {
    # Looks like the user has put the channel before the nick.
    # Rather than error, let's just switch the variables. :)
    ($for_user, $for_chan) = ($for_chan, $for_user);
  }

  if($for_chan !~ m/^#/) {
    # Looks like the user didn't specify a channel.
    # Use the current channel and put the grabbed word
    # back on the args to be used for the greet.

    unshift @args, $for_chan;
    $for_chan = $message->channel();
  }

  my $greet = join(' ', @args);

  my $dbh = $self->dbi()->dbh();
  my $sth = $dbh->prepare("
    INSERT INTO
      greets
    VALUES
      (NULL,?,?,?,?,?,0)
  ");

  my $result = $sth->execute($for_user, $greet, $for_chan, $message->nick(), time());

  if($result) {
    $self->respond($message, "Your greet for ".$for_user." in ".$for_chan." has been added.");
  } else {
    $self->respond($message, "Your greet wasn't added. Perhaps try !help +greet");
  }
}


sub delete_greet {
  my ($self, $message) = @_;
  my ($id) = split(/\s+/, $message->command_input());

  if($id !~ m/\d+/) {
    $self->respond($message, "Please specify the ID of the greet to be deleted.");
    exit;
  }

  my $level = 0; # User with a high enough level to delete anything
  my $user  = $self->search_or_create_user($message);

  if($user->{cmd_level} >= $self->config()->delete_level()) {
    $level = 1;
  }

  my $dbh = $self->dbi()->dbh();
  my $sth = $dbh->prepare("
    DELETE FROM
      greets
    WHERE
      id=?
    AND
      ((user=? OR added_by=?)
    OR
      $level)
  ");

  my $result = $sth->execute($id, $message->nick(), $message->nick());

  if($result) {
    $self->respond($message, "The greet was deleted.");
  } else {
    $self->respond($message, "The greet was not deleted. You can only delete greets that you added, or greets that are for you.");
  }
}


1;
