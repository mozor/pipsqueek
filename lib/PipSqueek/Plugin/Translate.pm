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
	
  my $url = 'http://translate.google.com/translate_t';
  my $text = $message->command_input();
  my ($from, $to, $pair) = '';
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


  # Sort out special variables first.
  if($text =~ m/^(~?[\^\$]{1})[2|](~?[\^\$]{1})/i) {
    if($1 eq $2) {
      $self->respond($message, "There's nothing to translate.");
      return;
    } else {
      $self->respond($message, "Ok, now I need to implement this stuff.");
    }
  }

  # Every language on Google has 2 letters designating it, except for
  # simplified Chinese which uses zh-CN. Go figure.
  if($text =~ m/^([a-z-]{2,})[2|]([a-z-]{2,})\s+(.*)$/i) {
    $pair = "$1|$2";
    $from = $1;
    $to = $2;
    $text = $3;
  } else {
    $pair = "fr|en";
    $from = "fr";
    $to = "en";
    $text = "Le singe est sur le branch.";
    # We need to guess the language. If it's anything but English then
    # we translate to English for the hell of it.
    # If the input _is_ English then we translate to whatever language
    # the user last translated into.
  }

  $url .= "?langpair=$pair&text=$text";

  my $browser  = LWP::UserAgent->new( 'agent' => 'Mozilla/5.0' );
  my $response = $browser->post($url);

  unless($response->is_success() &&
         $response->content_type() eq 'text/html' ) {
    $self->respond($message, "HTTP Error or Invalid Content: $url");
    return;
  }

  my $results = $response->content();

  my ($output) = $results =~ m/<textarea.*?>(.*?)<\/textarea>/is;
  $output =~ s/\s+$//;

  if(defined($output) && $output ne "") {
    $self->respond($message, '"' . $output . '"');
  } else {
    $self->respond($message, "Failed to translate");
  }

  return;
}


1;

__DATA__
english (
I
if
is
we
you
the
their
there
they
are
not
will
can
yes
no
should
could
might
may
want
to
too
go
in
on
an
good)

french (
oui
non
le
les
bon
ou
es
la
et
tu
tres
bien
jai)

german (
ja
nein
oder
ich
du
hast
man
kann
wie
bist
das
der
gut
sehr
warum
auf)
__END__
