package PipSqueek::Plugin::Jabber::Admin;
use base qw(PipSqueek::Plugin);

use strict;

use POE;
use POE::Component::Jabber::Error; 			#include error constants
use POE::Component::Jabber::Status; 			#include status constants
use POE::Component::Jabber::ProtocolFactory;		#include connection type constants
use POE::Filter::XML::Node; 				#include to build nodes
use POE::Filter::XML::NS qw/ :JABBER :IQ /; 		#include namespace constants
use POE::Filter::XML::Utils; 				#include some general utilites

use Filter::Template; 					#this is only a shortcut
const XNode POE::Filter::XML::Node

sub plugin_initialize {
 my $self=shift;
 $self->plugin_handlers('multi_join'	=> 'join',
			'multi_part'	=> 'part',
			'multi_say'	=> 'say',
			'multi_get_chatrooms'	=> 'get',
			'multi_set_status'	=> 'status',
			'multi_invite'	=> 'send_invite',
			'multi_topic'	=> 'change_subject',
			'multi_kick'	=> 'role',
			'multi_privup'	=> 'role',
			'multi_privdown'	=> 'role',
			'multi_get_ban_list'	=> 'get_ban_list',
			'multi_ban'	=> 'affiliation',
			'multi_unban'	=> 'affiliation',
			'multi_member'	=> 'affiliation',
			'multi_setlevel'	=> 'setlevel',
			'multi_rehash'	=> 'rehash',
			'multi_help_admin'	=> 'help_admin',
			);
 $self->client->kernel->state('output_ban_list',$self,'output_ban_list');
 }

sub help_admin {
 my ($self,$message)=@_;
 my $help="\nUse !join [alias] <chatroom[/nick]>[:password] to join chatroom. The nick will be taken from config file if not defined. If alias not defined it will be equal <chatroom>. Example: !join ThisChatroom thecoolestroom\@thecoolestjabberserver.com/botteg\n";
 $help.="Use !part [alias] to part chatroom/ Example: !part_chatroom ThisChatroom\n";
 $help.="Use !say [private] <destination> <text> to say something to the destination. The destination may be: jid (ex nick\@server.com) and than you must set private flag; alias of the chatroom without private flag; chatroom/nick (with or without private flag). Example: !say private nick\@server.com WOW!, !say ThisChatroom WOW!, !say chatroom/nick WOW!\n";
 $help.="Use !get_chatrooms to get list of chatrooms with its aliases.\n";
 $help.="Use !set_status [alias] <status> to change bot status.\n";
 $help.="Use !invite [alias] <jid> [invite_message] to invite someone to the chatroom with alias defined by !join.\n";
 $help.="Use !topic [alias] <subject> to set the chatroom subject.\n";
 $help.="Use !kick [alias] <nick> to kick nick from chatroom.\n";
 $help.="Use !privup [alias] <nick> or !privdown <alias> <nick> to change privelegies (visitor, participant, moderator sequently).\n";
 $help.="Use !get_ban_list [alias] to get ban list in private chat.\n";
 $help.="Use !ban [alias] <nick> to ban nick's jid from chatroom with alias defined by !join.\n";
 $help.="Use !unban [alias] <jid> to delete ban from defined jid from chatroom.\n";
 $help.="Use !member [alias] <nick> to give membership to nick's jid in chatroom.";
 $self->respond($message,$help);
 }

# Return PipSqueek::Jabber_Message object with channel method returns right chatroom address
# or 0. Use it with functions where the first parameter must be alias or chatroom.
sub solve_alias {
 my ($self,$message)=@_;
 my $heap=$self->client->get_heap();
 my $command_input=$message->command_input();
 my ($may_be_alias)=split(/\s+/,$command_input);
 my ($key) = grep {$_ eq $may_be_alias} keys %{$heap->{'chatrooms'}};
 if ($key) {
  my $chatroom=$heap->{'chatrooms'}{$key};
  $chatroom=~s/\/.*$//;
  $message->channel($chatroom);
  $command_input=~s/^\Q$may_be_alias\E\s*//;
  $message->command_input($command_input);
  return $message;
  }
 elsif (!$key and $message->channel()) {return $message;}
 else {
  if ($may_be_alias=~/^.*?\@[^\/]*$/) {
   ($key) = grep {$_ =~ /^\Q$may_be_alias\E\//} values %{$heap->{'chatrooms'}};
   $command_input=~s/^\Q$may_be_alias\E\s*// if $key;
   }
  if (!$key) {
   $may_be_alias=$message->sender();
   ($key) = grep {$_ =~ /^\Q$may_be_alias\E\//} values %{$heap->{'chatrooms'}};
   }
  if ($key) {
   $key=~s/\/.*$//;
   $message->channel($key);
   $message->command_input($command_input);
   return $message;
   }
  else {
   $self->respond($message,"No chatrooms detected. The first argument must be alias or chatroom. Use '!get_chatrooms' to get it or '!help_admin' to get help for admin functions.");
   return 0;
   }
  }
 }

sub get_self_info {
 my ($self,$chatroom)=@_;
 return unless $chatroom;
 my $heap=$self->client()->get_heap();
 my %roles_hash=('visitor'=>0,'participant'=>1,'moderator'=>2);
 my ($username)=grep {$_ =~ /^\Q$chatroom\E\//} values %{$heap->{'chatrooms'}};
 $username=~s/.*\///;
 my $my_info=$heap->{'chatroom_users'}{$chatroom}{$username};
 return $my_info;
 }

sub join {
 my ($self,$message)=@_;
 my $heap=$self->client->get_heap;
 if ($message->command_input!~/^(?:(\w+)\s+)?(\w+\@[.\w]+(?:\/[^\s]+)?)/) {
  $self->respond($message,"Use !join [alias] <chatroom[/nick]>[:password] to join chatroom. The nick will be taken from config file if not defined. If alias not defined it will be equal <chatroom>. Use '!help_admin' to get help for admin functions.");
  return;
  }
 my ($name,$chatroom)=($1,$2);
 $message->command_input($chatroom);
 $chatroom=~s/:.*$//;
 $name ||= $chatroom;
 my ($key) = grep {$heap->{'chatrooms'}{$_} eq $chatroom} keys %{$heap->{'chatrooms'}};
 delete($heap->{'chatrooms'}{$key}) if $key;
 $heap->{'chatrooms'}{$name}=$chatroom;
 $self->client->kernel->yield('join_chatroom',$message->command_input());
 }

sub part {
 my ($self,$message)=@_;
 #$self->respond($message,"Part chatroom ".$message->command_input());
 if (!ref($message=$self->solve_alias($message))) {return;}
 my $leave_message=$message->command_input;
 my $chatroom=$message->channel();
 my $chatrooms=$self->client->get_heap()->{'chatrooms'};
 my ($key)= grep {$chatrooms->{$_} =~ /^\Q$chatroom\E/} keys %$chatrooms;
 delete($self->client->get_heap->{'chatrooms'}{$key});
 my $node=XNode->new('presence');
 $node->attr('to',$chatroom);
 $node->attr('type','unavailable');
 $node->insert_tag('status')->data($leave_message) if $leave_message;
 $self->client->kernel->post($self->client->JABBER_CLIENT_ALIAS(), 'output_handler',$node);
 }

sub get {
 my ($self,$message)=@_;
 use Data::Dumper; 
 $self->respond($message,Dumper($self->client->get_heap->{'chatrooms'}));
 }

sub say {
 my ($self,$message)=@_;
 my ($private,$chatroom,$mes);
 if ($message->command_input()!~/^private\s/) {
  if (!ref($message=$self->solve_alias($message))) {return;}
  $private=0;
  ($chatroom,$mes)=($message->channel(), $message->command_input());
  }
 else {
  ($private,$chatroom,$mes)=split(/\s+/,$message->command_input());
  }
 if ($chatroom) {
  $message->nick($chatroom);
  $chatroom=~s/\/.*$//;
  $message->sender($chatroom);
  }
 if ($private) {$message->type('chat');}
 else {$message->type('groupchat');}
 $self->respond($message,$mes);
 }

sub status {
 my ($self,$message)=@_;
 if (!ref($message=$self->solve_alias($message))) {return;}
 my ($chatroom,$status)=($message->channel(),$message->command_input());
 my $node=XNode->new('presence');
 $node->attr('to',$chatroom );
 $node->insert_tag('show')->data('xa');
 $node->insert_tag('status')->data($status);
 $self->client->kernel->post($self->client->JABBER_CLIENT_ALIAS(), 'output_handler',$node);
 }

sub send_invite {
 my ($self,$message)=@_;
 if (!ref($message=$self->solve_alias($message))) {return;}
 my $chatroom=$message->channel();
 my $self_affiliation=$self->get_self_info($chatroom)->{'affiliation'};
 if (!grep {$self_affiliation eq $_} ("owner","admin")) {$self->respond($message,"I haven't enough privelegies. I'm not admin of this chatroom."); return;}
 my ($user, $reason)=split(/\s+/,$message->command_input(),2);
 my $node=XNode->new('message');
 $chatroom=~s/\/.*$//;
 $node->attr('to',$chatroom);
 $node->insert_tag('x')->attr('xmlns','http://jabber.org/protocol/muc#user');
 $node->get_tag('x')->insert_tag('invite')->attr('to',$user);
 $node->get_tag('x')->get_tag('invite')->insert_tag('reason')->data($reason);
 $self->client->kernel->post($self->client->JABBER_CLIENT_ALIAS(), 'output_handler',$node);
 }

sub change_subject {
 my ($self,$message)=@_;
 if (!ref($message=$self->solve_alias($message))) {return;}
 my ($chatroom,$subject)=($message->channel(),$message->command_input());
 if ($self->get_self_info($chatroom)->{'role'} ne "moderator") {$self->respond($message,"I haven't enough privelegies. I'm not moderator in this chatroom."); return;}
 my $node=XNode->new('message');
 $chatroom=~s/\/.*$//;
 $node->insert_attrs(['to',$chatroom,'type','groupchat']);
 $node->insert_tag('subject')->data($subject);
 $self->client->kernel->post($self->client->JABBER_CLIENT_ALIAS(), 'output_handler',$node);
 }

sub role {
 my ($self,$message)=@_;
 #print "COMMAND: ".$message->command."\n";
 if (!ref($message=$self->solve_alias($message))) {return;}
 my $chatroom=$message->channel();
 if ($self->get_self_info($chatroom)->{'role'} ne "moderator") {$self->respond($message,"I haven't enough privelegies. I'm not moderator in this chatroom."); return;}
 my ($user)=split(/\s+/,$message->command_input());
 if (!exists($self->client->get_heap->{'chatroom_users'}{$chatroom}{$user})) {
  $self->respond($message,"Can't found this nick in chatroom.");
  return;
  }
 if ($message->command() eq 'kick') {$self->change_role($message,'none','kick'); return;}

 my @roles_arr=('visitor','participant','moderator');
 my %roles_hash=('visitor'=>0,'participant'=>1,'moderator'=>2);
 use Data::Dumper; print Dumper $self->client->get_heap->{'chatroom_users'}{$chatroom};
 my $user_role=$self->client->get_heap->{'chatroom_users'}{$chatroom}{$user}{'role'};
 if (!$user_role) {$self->respond($message,"Can't find user's role in this chatroom. Sorry."); return;}
 #print "USE ROLE: $user_role ";
 $user_role=$roles_hash{$user_role};
 #print "IS $user_role\n";
 if ($message->command() eq 'privup') {
  $user_role++;
  if ($user_role>=scalar(@roles_arr)) {$self->respond($message,"Can't do it! I don't know status higher than moderator!"); return;}
  $self->change_role($message,$roles_arr[$user_role],'change_priv');
  }
 elsif ($message->command() eq 'privdown') {
  $user_role--;
  if ($user_role<0) {$self->respond($message,"Can't do it! $user status is the smallest..."); return;}
  $self->change_role($message,$roles_arr[$user_role],'change_priv');
  }
 }

sub change_role {
 my ($self,$message,$role,$list)=@_;
 if (!$role) {$self->respond($message, "Can't change role: get no role."); return;}
 if (!ref($message=$self->solve_alias($message))) {return;}
 my $chatroom=$message->channel();
 my ($user, $reason)=split(/\s+/,$message->command_input(),2);
 if (!exists($self->client->get_heap->{'chatroom_users'}{$chatroom}{$user})) {
  $self->respond($message,"Can't found this nick in chatroom.");
  return;
  }
 my $node=XNode->new('iq');
 $node->insert_attrs(['to',$chatroom,'id',$list,'type',+IQ_SET]);
 $node->insert_tag('query')->attr('xmlns','http://jabber.org/protocol/muc#admin');
 $node->get_tag('query')->insert_tag('item')->insert_attrs(['nick',$user,'role',$role]);
 $node->get_tag('query')->get_tag('item')->insert_tag('reason')->data($reason);
 $self->client->kernel->post($self->client->JABBER_CLIENT_ALIAS(), 'output_handler',$node);
 }

sub affiliation {
 my ($self,$message)=@_;
 if ($message->command() eq 'ban') {$self->change_affiliation($message,'outcast');}
 elsif ($message->command() eq 'unban') {$self->change_affiliation($message,'none');}
 elsif ($message->command() eq 'member') {$self->change_affiliation($message,'member');}
 }

sub change_affiliation {
 my ($self,$message,$affiliation)=@_;
 if (!$affiliation) {$self->respond($message, "Can't change affiliation: get no affiliation."); return;}
 if (!ref($message=$self->solve_alias($message))) {return;}
 my ($chatroom,$trash)=($message->channel(),$message->command_input());
 my $self_affiliation=$self->get_self_info($chatroom)->{'affiliation'};
 print "I'M $self_affiliation\n";
 if (!grep {$self_affiliation eq $_} ("owner","admin")) {$self->respond($message,"I haven't enough privelegies. I'm not admin of this chatroom."); return;}
 my ($user,$reason)=split(/\s*:\s*/,$trash,2);
 my @users=split(/\s+/,$user);
 #use Data::Dumper; print Dumper $self->client->get_heap->{'chatroom_users'}->{$chatroom};
 foreach my $user (@users) {
  my $node=XNode->new('iq');
  my $jid= $message->command eq 'unban' ? $user : $self->client()->get_heap()->{'chatroom_users'}{$chatroom}{$user}{'jid'};
  if (!$jid) {
   $self->respond($message,"Can't get jid for user: $user");
   next;
   }
  $node->insert_attrs(['id','ban','to',$chatroom,'type',+IQ_SET]);
  $node->insert_tag('query')->attr('xmlns','http://jabber.org/protocol/muc#admin');
  $node->get_tag('query')->insert_tag('item')->insert_attrs(['affiliation', $affiliation, 'jid', $jid]);
  $node->get_tag('query')->get_tag('item')->insert_tag('reason')->data($reason);
  $self->client->kernel->post($self->client->JABBER_CLIENT_ALIAS(), 'output_handler',$node);
  }
 }

sub get_ban_list {
 my ($self,$message)=@_;
 if (!ref($message=$self->solve_alias($message))) {return;}
 my $chatroom=$message->channel();
 my $node=XNode->new('iq');
 $node->insert_attrs(['type',+IQ_GET,'to',$chatroom,'id',$message->nick()]);
 $node->insert_tag('query')->attr('xmlns','http://jabber.org/protocol/muc#admin');
 $node->get_tag('query')->insert_tag('item')->attr('affiliation','outcast');
 $self->client->kernel->post($self->client->JABBER_CLIENT_ALIAS(), 'return_to_sender','output_ban_list',$node);
 }

sub output_ban_list {
 my ($self,$node)=@_[OBJECT,ARG0];
 print $node->to_str(),"\n";
 return unless $node->get_tag('query');
 my $chatroom=$node->attr('from');
 my @items = $node->get_tag('query')->get_tag('item');
 my @jid;
 foreach my $item (@items) {
  next unless defined $item;
  push(@jid,$item->attr('jid'));
  }
 #my $type=($node->attr('id')!~/\// ? 'chat' : 'groupchat');
 $self->respond($node->attr('id'),"Banned jid: ".join(', ',@jid),'chat');
 }

sub rehash {
 my ($self,$message) = @_;
 $self->client()->kernel()->call( $self->client()->SESSION_ID(), 'plugins_load' );
 return $self->respond($message, "Bot rehashed");
 }

sub setlevel {
 my ($self,$message) = @_;
 my ($name,$level)=split(/\s+/, $message->command_input());

 if ($name && defined($level)) {
  my $user = $self->search_user($name);

  unless ($user) {
   $self->respond($message, "That user does not exist");
   return;
   }

  $user->{'cmd_level'} = $level;
  $self->update_user($user);
  }
 }

1;