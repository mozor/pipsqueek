package PipSqueek::Plugin::Heart;
use base qw(PipSqueek::Plugin);
use strict;

sub plugin_initialize {
  my $self = shift;

  $self->plugin_handlers([
      'irc_public'
  ]);
}


sub irc_public {
  my ($self,$message) = @_;

  my $bot_nick = $self->config()->current_nickname();

  if($message->message() =~ m/<3 $bot_nick/i) {
    $self->respond($message, 'I <3 you too, '.$message->nick());
  }
}

1;
