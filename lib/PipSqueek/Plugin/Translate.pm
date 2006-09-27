package PipSqueek::Plugin::Translate;
use base qw(PipSqueek::Plugin);

use URI::URL;
use LWP::UserAgent;

sub plugin_initialize {
  my $self = shift;
  $self->plugin_handlers({
    'multi_translate' => 'translate',
  });
}


sub translate {
  my ($self,$message) = @_;

  my $session_heap = $self->client()->get_heap();
  my $ltf = $session_heap->{'last_translated_from'};
  my $ltt = $session_heap->{'last_translated_to'};

  my $url = 'http://translate.google.com/translate_t';
  my $text = $message->command_input();
  my ($from, $to) = '';
  my $langs = {
                'arabic'      => 'ar',
                'ar'          => 'ar',
                'german'      => 'de',
                'deutsch'     => 'de',
                'de'          => 'de',
                'english'     => 'en',
                'en'          => 'en',
                'spanish'     => 'es',
                'es'          => 'es',
                'espanol'     => 'es',
                'french'      => 'fr',
                'francais'    => 'fr',
                'fr'          => 'fr',
                'italian'     => 'it',
                'it'          => 'it',
                'japanese'    => 'ja',
                'ja'          => 'ja',
                'korean'      => 'ko',
                'ko'          => 'ko',
                'portuguese'  => 'pt',
                'pt'          => 'pt',
                'chinese'     => 'zh-CN',
                'cn'          => 'zh-CN',
                'zh-CN'       => 'zh-CN'
              };

  if($text =~ m/^(~?[\^\$]{1}|[a-z-]{2,})
                [2|](~?[\^\$]{1}|[a-z-]{2,})
                \s+(.*)$/ix) {

    if($1 eq $2) {
      return($self->respond($message, "There's nothing to translate."));
    }

    if($1 eq '^') {
      $from = $session_heap->{'last_translated_from'};
    } elsif($1 eq '$') {
      $from = $session_heap->{'last_translated_to'};
    } elsif($2 eq '^') {
      $to = $session_heap->{'last_translated_from'};
    } elsif($2 eq '$') {
      $to = $session_heap->{'last_translated_to'};
    }

    if(!$from) {
      $from = $langs->{$1};
    }

    if(!$to) {
      $to = $langs->{$2};
    }
    
    $text = $3;
  } else {
    return($self->respond($message, "Try using the help (which Stu hasn't actually written yet)."));
  }

  $url .= "?langpair=$from|$to&text=$text";

  $session_heap->{'last_translated_from'} = $from;
  $session_heap->{'last_translated_to'} = $to;

  my $browser  = LWP::UserAgent->new('agent' => 'Mozilla/5.0');
  my $response = $browser->post($url);

  unless($response->is_success() &&
         $response->content_type() eq 'text/html') {
    $self->respond($message, "HTTP Error or Invalid Content: $url");
    return;
  }

  my $results = $response->content();

  my ($output) = $results =~ m/<textarea.*?>(.*?)<\/textarea>/is;
  $output =~ s/\s+$//;

  if(defined($output) && $output ne "") {
    $self->respond($message, "\"$output\"");
  } else {
    $self->respond($message, "Failed to translate");
  }

  return;
}


1;

__END__
