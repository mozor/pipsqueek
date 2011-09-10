package PipSqueek::Plugin::Response;
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

        if($message->message() =~ m/oh no/i) {
                $self->respond($message, $message->nick() . ': OH YEAAHHHHH!');
        }
#       if($message->message() =~ m/larry/i) {
#               $self->respond($message, $message->nick() . ': youknowwhatimean');
#       }
        if($message->message() =~ m/darrin/i) {
                $self->respond($message, $message->nick() . ': DONT SPEAK OF HIM!');
        }
#       if($message->message() =~ m/logan/i) {
#               return $self->respond($message, '<|meh|> TLDR; Logan destroyed it');
#       }
        if($message->message() =~ m/chamber #5 of 6/i) {
                $self->respond($message, '^_^: chamber #1 of 6 => +click+');
        }
}

1;

