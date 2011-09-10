package PipSqueek::Plugin::Greetings;
use base qw(PipSqueek::Plugin);

sub config_initialize
{
    my $self = shift;
    $self->plugin_configuration('time_to_remember' => '30');
}

sub plugin_initialize
{
    my $self = shift;
     #my $dbh=$self->dbi()->dbh();
     #my $sth=$dbh->prepare("ALTER TABLE greetings ADD channel VARCHAR ");
     #$sth->execute();
    $self->plugin_handlers('irc_join'=>'greet',
			'multi_+greet'=>'add_greet',
			'multi_-greet'=>'del_greet',
			'multi_show_greet'=>'show_greet',
			'multi_greet'=>'help');

    my $schema = [
		[ 'id', 'INTEGER PRIMARY KEY AUTOINCREMENT'],
        [ 'user', 'VARCHAR' ],
        [ 'greet', 'VARCHAR' ],
		[ 'channel', 'VARCHAR' ],
    ];

    $self->dbi()->install_schema('greetings', $schema);
}

sub help 
{
    my ($self,$message)=@_;
    my $help="To set, remove or show greets use +greet <nick> [chan] <greet> | -greet <id> | show_greet [nick]";
    $self->respond($message,$help);
}

sub greet {
    my ($self,$message)=@_;
    my $nick=$message->nick();
    my $temp;
    if (exists($self->{'join'})) { ($temp) = grep {if ($_->{'nick'} eq $nick and $_->{'channel'} eq $message->channel()) {$_}} @{$self->{'join'}}; }
    if ( !$temp or (time()-$temp->{'join_time'}) >= $self->config()->time_to_remember()*60 ) {
  my $dbh = $self->dbi()->dbh();
  my $sth = $dbh->prepare("SELECT greet FROM greetings WHERE user = ? and channel = ? ORDER BY RANDOM() LIMIT 1");
  my $result = $sth->execute($nick, $message->channel());
  my $row = $sth->fetchrow_arrayref();
  if ($row) {
   $self->client()->privmsg($message->channel(), $message->nick().": ".$row->[0]);
   if (!$temp) {push ( @{$self->{'join'}} , { 'nick' => $nick, 'channel' => $message->channel(), 'join_time' => time() } ); }
   else { $temp->{'join_time'} = time(); }
   }
  }
    }

sub add_greet {
    my ($self,$message)=@_;
    my @temp = split(/\s+/, $message->command_input());
    my $nick = shift @temp;
    if ($nick =~ /^#/) {$self->respond($message, 'Bad nick given, please correct. Use !+greet <nick> [chan] <greet>'); return; }
    my $chan;
    if ($temp[0] =~ m/^#/) { $chan = shift @temp; } else { $chan = $message->channel(); }
    if (!$chan) { $self->respond($message, 'Please set the channel for this greet'); return; }
    my $dbh = $self->dbi()->dbh();
    my $sth = $dbh->prepare("INSERT INTO greetings values (null,?,?,?)");
    my $result = $sth->execute($nick, join (' ',@temp), $chan);
    $self->respond($message, 'Your Greet successfully added.') if $result eq "1";
}

sub show_greet {
    my ($self,$message)=@_;
    my ($nick) = split(/\s+/, $message->command_input());
    if (!$nick) {$nick = $message->nick();}
    my $dbh = $self->dbi()->dbh();
    my $sth = $dbh->prepare("SELECT id, channel, greet FROM greetings WHERE user = ?");
    my $result = $sth->execute($nick);
    while (my $row = $sth->fetchrow_arrayref()) {
    $self->respond($message, $row->[0].' '.$row->[1].' '.$row->[2]); }
}

sub del_greet {
    my ($self,$message)=@_;
    my ($id) = split(/\s+/, $message->command_input());
    if ($id !~ /^\d+$/) {$self->respond($message, 'Wrong id is given, please correct. Use !show_greet [nick]'); }
    my $dbh = $self->dbi()->dbh();
    my $sth = $dbh->prepare("DELETE FROM greetings WHERE id = ?");
    my $result = $sth->execute($id);
    $self->respond($message, 'Your Greet successfully deleted.') if $result;
}

1;
