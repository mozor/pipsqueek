package PipSqueek::Plugin::Jabber::PipSqueek;
use base qw(PipSqueek::Plugin);

use POE;
use File::Spec::Functions qw(catfile);
use strict;

sub plugin_initialize {
 my $self=shift;
 $self->plugin_handlers('input_event'	=> 'input_event',
			);
 $self->_load_levels_conf();
 
 my $schema = [
        [ 'id',     'INTEGER PRIMARY KEY' ],
        [ 'username',    'VARCHAR NOT NULL' ],
        [ 'nickname',    'VARCHAR NOT NULL' ],
        [ 'ident',    'VARCHAR' ],
        [ 'host',    'VARCHAR' ],
        [ 'password',     'VARCHAR' ],
        [ 'logged_in',    'INT NOT NULL DEFAULT 0' ],
        [ 'identified',    'INT NOT NULL DEFAULT 0' ],
        [ 'last_seen',    'TIMESTAMP' ],
        [ 'seen_data',    'VARCHAR' ],
        [ 'created',    'TIMESTAMP NOT NULL' ],
        [ 'cmd_level',    'INT NOT NULL DEFAULT 10' ],
    ];

 $self->dbi()->install_schema('users', $schema);
 }

sub input_event() {
 my ($self,$node) = @_;

 my $heap=$self->client->get_heap();
 my $type=$node->attr('type');

 print "\n===PACKET RECEIVED===\n";
 print $node->to_str() . "\n";
 print "=====================\n\n";

 if ($self->client()->CONFIG()->automatically_subscribe() and $node->name=~/^presence$/i and $type=~/^subscribe$/i) {
  print "ASK FOR SUBSCRIBTION FROM ".$node->attr('from')."\n";
  $self->client->kernel->yield('send_presence', $node->attr('from'), 'subscribed');
  $self->client->kernel->yield('add_to_roster',$node->attr('from'));
  $self->client->kernel->yield('roster_request');
  }

 if ($node->name eq "presence" and $type ne "error" and $node->get_tag('x')) {
  return unless $node->get_tag('x')->get_tag('item');
  my ($chatroom,$nick)=split(/\//,$node->attr('from'));
  if ($type eq 'unavailable') {delete($heap->{'chatroom_users'}{$chatroom}{$nick});}
  else {
   my $hash=$node->get_tag('x')->get_tag('item')->get_attrs();
   foreach my $key (keys %$hash) {
    $heap->{'chatroom_users'}{$chatroom}{$nick}{$key}=$hash->{$key};
    }
   }
  use Data::Dumper; print Dumper $heap->{'chatroom_users'}{$chatroom};
  }

 elsif ($node->name=~/^presence$/i and $type=~/^unsubscribed$/i) {
  $self->client->kernel->yield('send_presence', $node->attr('from'), 'unsubscribed');
  delete($heap->{'roster'}->{$node->attr('from')});
  $self->client->kernel->yield('remove_from_roster',$node->attr('from'));
  }

 elsif ($node->name=~/^message$/i) {
  my $message=PipSqueek::Jabber_Message->new($node);
  if ($message->is_command()) {$self->_delegate_command($message);}
  }
 }

sub jid_wanted {
 my ($self,$message)=@_;
 my $heap=$self->client->get_heap();
 my $nick;
 my ($chatroom,$chatnick) = $message->nick()=~/^(.*?)\/(.*)$/;
 my ($key)=grep {$_ =~ /^\Q$chatroom\E\//} values %{$heap->{'chatrooms'}};
 if ($key) {
  $nick=$heap->{'chatroom_users'}{$chatroom}{$chatnick}{'jid'};
  $nick=~s/\/.*$//;
  }
 else {$nick=$message->sender();}
 return $nick;
 }

sub _delegate_command {
 my ($self,$message)=@_;

 my $c_access=$self->client->CONFIG->default_access_level();
 my $public=($message->type() eq "groupchat" ? 1 : 0);
 my $nick=$self->jid_wanted($message); my $user;

 if (!$nick and $c_access) {$self->client()->privmsg($message,"Can't get your jid. If you're in chatroom, maybe I'm not moderator. So you haven't enough level to exec this command. Try it into jabber private."); return;}
 elsif ($nick) {
  #print "Now, nick is $nick!!!\n";
  $user=$self->search_or_create_user($nick);
  $user->{'last_seen'}=time();
  $user->{'seen_data'}='saying: '.$message->message();
  $self->update_user($user);
  }

 #print "Your level is: ",$user->{'cmd_level'},"\n";
 #use Data::Dumper; print Dumper $self->{'LEVELS'};
 my $level = $self->{'LEVELS'}->{$message->command()} || $c_access;
 if ($user->{'cmd_level'} < $level) {
  $self->client()->privmsg($message->nick(), "This command requires a command level of $level. You currently have a level of ".$user->{'cmd_level'}+0);
  if (!$nick) {$self->client()->privmsg($message,"Can't get your jid for getting level. If you're in chatroom, maybe I'm not moderator. Try command into jabber private.");}
  return;
  }
 
 if (!$public) {$self->client->kernel->yield("private_".$message->command(), $message);}
 else {
  my $channel=$message->channel();
  my $command=$message->command();
  if (exists($self->{'CHANNELS'}->{$command}) and scalar(@{$self->{'CHANNELS'}->{$command}})!=0 and !grep(/$channel/,@{$self->{'CHANNELS'}->{$command}})) {
   $self->respond($message,"Current chatroom can't use this command.");
   return;
   }
  $self->client->kernel->yield("public_".$command, $message);
  }
 }

#-- some helper functions --#
sub _load_levels_conf {
 my $self = shift;
 my $loaded = 0;

 foreach my $dir ($self->client->ROOTPATH(), $self->client->BASEPATH()) {
  my $file = catfile( $dir, '/etc/levels.conf' );
  if( -e $file ) {
   $self->_merge_levels_conf_file( $file );
   $loaded = 1;
   }
  }

 unless ($loaded) {
  warn "Unable to find levels_jabber.conf\n";
  }
 }

sub _merge_levels_conf_file {
 my ($self,$file) = @_;

 open( my $fh, '<', $file ) or die "Unable to open '$file': $!";
 my @lines = <$fh>;
 chomp(@lines);
 close( $fh );

 foreach my $line (grep(/=/,@lines)) {
  $line=~m/^\s*(\w+)\s*=\s*(\d+)\s*(.*)$/;
  my ($k,$v) = ($1,$2);
  $self->{'LEVELS'}->{$k} = $v;
  $self->{'CHANNELS'}->{$k} = [split(/[,\s]+/,$3)];
  }
 }

1;
