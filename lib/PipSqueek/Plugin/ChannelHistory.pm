package PipSqueek::Plugin::ChannelHistory;
use base qw(PipSqueek::Plugin);

use strict;

sub config_initialize {
 my $self=shift;
 $self->plugin_configuration('max_num_rows' => 100);
 }

sub plugin_initialize {
 my $self=shift;
 $self->plugin_handlers('irc_public'=>'set', 'multi_history'=>'get');
 }

sub set {
 my ($self,$message)=@_;
 my $config=$self->config();
 if ($message->can('channel') and $message->channel() and $message->nick()) {
  if (!exists($self->{$message->channel()})) {$self->{$message->channel()}=[];}
  if (scalar(@{$self->{$message->channel()}}) >= $config->max_num_rows()) {shift(@{$self->{$message->channel()}});}
  my @time=localtime(time); my $str_time=join(':',reverse @time[0..2]);
  push(@{$self->{$message->channel()}}, $str_time." ".$message->nick().": ".$message->message());
  }
 }

sub get {
 my ($self,$message)=@_;
 my ($num,$channel)=split(/\s+/,$message->command_input());
 if (!$channel and $message->can('channel')) {$channel=$message->channel();}
 if ($channel!~/^#/ or $num!~/^\d+$/) {$self->respond($message,"Use '!history <num_rows> [channel]' to get last channel lines."); return;}
 if (!exists($self->{$channel})) {$self->respond($message,"Sorry, maybe I'm not on this channel and can't log it."); return;}
 my ($max)=sort {$a<=>$b} ($self->config()->max_num_rows(),scalar(@{$self->{$channel}}),$num);
 my $end=scalar(@{$self->{$channel}});
 for (my $i=$end-$max;$i<$end;$i++) {
  $self->client()->privmsg($message->nick(),$self->{$channel}->[$i]);
  }
 }

1;
