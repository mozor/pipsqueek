package PipSqueek::Plugin::Timer;
use base qw(PipSqueek::Plugin);

use strict;
use POE;

sub plugin_initialize {
 my $self=shift;
 my $schema = 	[
        	[ 'id', 'INTEGER PRIMARY KEY AUTOINCREMENT' ],
		[ 'session', 'VARCHAR(10)' ],
		[ 'time', 'VARCHAR' ],
        	[ 'destination', 'VARCHAR' ],
		[ 'command_text', 'VARCHAR' ],
    		];
 $self->dbi()->install_schema('timer', $schema);
 $self->plugin_handlers('private_set_timer'=>'set_timer',
			'private_show_timer'	=> 'show_timer',
			'private_del_timer'	=> 'del_timer',
			);
 $self->client()->kernel()->state('timer_startup',$self,'timer_startup');

 my $dbh=$self->dbi()->dbh();
 my $sth; my $command;
 $command="SELECT time,destination,command_text FROM timer WHERE session=?";
 $sth=$dbh->prepare($command);
 unless ($sth) {print $dbh->errstr(); return;}
 my $whoami=$self->client()->get_heap()->{'whoami'} || 'irc';
 $sth->execute($whoami);
 while (my $row = $sth->fetchrow_arrayref()) {
  #print "SET TIMER: ",join(' ',@$row),"\n";
  my $delay=$self->define_next_time($row->[0]) - time();
  $self->client()->kernel()->delay_set('timer_startup',$delay,@$row);
  }
 }

sub set_timer {
 my ($self,$message)=@_;
 my ($timer,$dest,$command);
 if ($message->command_input() =~ m/^((?:[*\/\d]+\s+){5})([^\s]+)\s+(.*)$/) {
  ($timer,$dest,$command) = ($1,$2,$3);
  $timer=~s/^\s*|\s*$//g;
  }
 else {$self->respond($message, "Use '!set_timer <* * * * *> <destination> <message>' where <* * * * *> means setting timer like a crontab. Example: '!set_timer 00 12 * * * mynick !bash' will imitate saying '!bash' to bot in private of mynick at 12 o'clock every day."); return;}
 my @time=split(/\s+/,$timer);
 if (grep {$_ !~ m/^\*|\d+|\*\/\d+$/} @time) {$self->respond($message, "Use time mask: * for all, number for defined value and */numer to set timer on every value devided by number."); return;}
 if ($time[0]=~m/^(\*|\*\/1)$/) {$self->respond($message, "You can't set timer on every minute."); return;}
 if (grep(/^*\/0$/,@time)) {$self->respond($message, "Divizion by zero?"); return;}
 my $dbh = $self->dbi()->dbh();
 my $sth = $dbh->prepare("INSERT INTO timer (time,destination,command_text,session) VALUES (?,?,?,?)");
 my $whoami=$self->client()->get_heap()->{'whoami'} || 'irc';
 my $success=$sth->execute($timer,$dest,$command,$whoami);
 $self->respond($message, "Your Timer successfully added.") if $success;
 my $delay=$self->define_next_time($timer) - time();
 $self->client()->kernel()->delay_set('timer_startup',$delay,$timer,$dest,$command);
 }

sub del_timer {
 my ($self,$message)=@_;
 my ($id) = split(/\s+/, $message->command_input());
 if ($id !~ /^\d+$/) {$self->respond($message, 'Wrong id is given, please correct. Use !show_timer <destination>'); }
 my $dbh = $self->dbi()->dbh();
 my $sth = $dbh->prepare("DELETE FROM timer WHERE id=? AND session=?");
 my $whoami=$self->client()->get_heap()->{'whoami'} || 'irc';
 my $result = $sth->execute($id,$whoami);
 if ($result) {$self->respond($message, 'This Timer successfully deleted.');}
 }

sub show_timer {
 my ($self,$message)=@_;
 my $whoami=$self->client()->get_heap()->{'whoami'} || 'irc';
 my $sql="SELECT id,destination,time,command_text FROM timer WHERE session='$whoami'";
 if ($message->command_input()) {
  my @dest=split(/,|\s+|,\s+/, $message->command_input());
  $sql.=" AND (destination='".join("' OR destination='",@dest)."')";
  }
 my $dbh = $self->dbi()->dbh();
 my $sth = $dbh->prepare($sql);
 $sth->execute();
 while (my $row = $sth->fetchrow_arrayref()) {$self->respond($message,join('  ',@$row));}
 }

sub timer_startup {
 my ($self,$timer,$dest,$command)=@_[OBJECT,ARG0,ARG1,ARG2];
 #print "TIMER STARTUP WORKING: ",$timer,' ',$dest,' ',$command,"\n";
 my $send_message;
 if ($self->client()->get_heap()->{'whoami'} ne 'Jabber') { 
  my ($event,$sender,$to);
  if ($dest=~m/^#/) {$event='irc_public'; $sender=$self->client()->CONFIG()->current_nickname()."!*@*"; $to=$dest;}
  else {$event='irc_msg'; $sender=$dest."!*@*"; $to=$self->client()->CONFIG()->current_nickname();}
  $send_message=[$sender, [ $to ], $command];
  $self->client()->kernel()->call($self->client()->SESSION_ID(), $event, @$send_message);
  }
 else {
  $send_message=POE::Filter::XML::Node->new('message');
  $send_message->attr('to', $self->client()->CONFIG()->identity_nickname());
  $send_message->attr('from', $dest);
  $send_message->attr('type', 'chat');
  Encode::_utf8_on($command);
  $send_message->insert_tag('body')->data($command);
  $self->client()->kernel()->call($self->client()->SESSION_ID(), 'input_event', $send_message);
  }
 my $delay=$self->define_next_time($timer) - time();
 #print "NOW TIME: ".time()."\nNEW TIME: ".(time()+$delay)."\nDELAY SET: $delay\n";
 $self->client()->kernel()->delay_set('timer_startup',$delay,$timer,$dest,$command);
 }

sub define_next_time {
 my ($self,$timer)=@_;
 use Schedule::Cron::Events;
 my $cron=new Schedule::Cron::Events($timer, Seconds => time()+60);
 my @mktime=$cron->nextEvent();
 use Time::Local;
 return timelocal(@mktime);
 }

sub plugin_teardown {
 my $self = shift;
 $self->client()->kernel()->delay('timer_startup');
 }

1;
