package PipSqueek::Jabber_Message;
use base 'Class::Accessor::Fast';
use strict;

sub new {
 my $proto = shift;
 my $class = ref($proto) || $proto;
 my $self  = bless( {}, $class );

 $self->mk_accessors(
	qw( sender nick ident host recipients
	channel message raw event
	is_command command command_input
	_config )
    );

 my $node=shift;
 if (ref($node)) {$self->parse($node);}
 else {return 0;}

 return $self;
 }

# the same as in IRC
sub parse {
 my ($self,$node)=(@_);
	
 # save the sender info
 $self->sender($node->attr('from'));

 # parse a nick!ident@hostmask sender into appropriate fields
 if ($self->sender() =~ /^(.*?)\@(.*?)$/) {
  my $nick=$self->sender();
  $nick=~s/\/.+$//;
  $self->nick($nick);
  $self->ident($1);
  $self->host($2);
  }

 my @recipients;
 push(@recipients,$self->sender());
 $self->recipients(@recipients);

 if($node->to_str() =~ /<body>(.*?)<\/body>/ && !defined($self->message()) ) {
  $self->message($1);
  }

 # is this message a command? 
 my $prefixed="[!#+&]";
 my $c_answer=1;
 $node->get_attrs()->{'to'} =~ m/^(.*?)\@(.*?)$/;
 my $nickname=$1;

 my $command = undef;
 my $c_input = undef;
 my $input = $self->message();

 # !quote
 if( $prefixed && $input =~ /^$prefixed/i ) {
  $input =~ s/^$prefixed//i;
  ($command,$c_input) = $input =~ m/^(.*?)(?:\s+(.*))?$/;
  }
 # PipSqueek: !quote, PipSqueek: quote, or PipSqueek, quote
 elsif( $c_answer && $input =~ /^$nickname[:,]/i ) {
  $input =~ s/^$nickname[:,]\s*//i;
  ($command,$c_input) = $input =~ m/^(.*?)(?:\s+(.*))?$/;
  $command =~ s/^$prefixed//;
  }

 if ($command) {
  $self->is_command($command);
  $self->command($command);
  $self->command_input($c_input);
  }

 return 1;
 }

1;
