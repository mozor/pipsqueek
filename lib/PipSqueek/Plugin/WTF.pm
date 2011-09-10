package PipSqueek::Plugin::WTF;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
  my $self = shift;

    $self->plugin_handlers({
    'multi_acronym' => 'get_wtf',
        'multi_wtf'     => 'get_wtf',
    'multi_+wtf'    => 'add_wtf',
    'multi_-wtf'    => 'del_wtf',
    'multi_#wtf'    => 'num_wtf',
    });

  my $schema = [
    ['id', 'INTEGER PRIMARY KEY'],
    ['acronym', 'VARCHAR NOT NULL'],
    ['definition', 'VARCHAR NOT NULL'],
  ];

    if($self->dbi()->install_schema('wtf', $schema)) {
        my $sql =
    'INSERT INTO wtf (acronym,definition) VALUES(?,?)';

        my $sth = $self->dbi()->dbh()->prepare($sql);

        foreach my $line (<DATA>) {
            chomp($line);
            my (@values) = split(/ /, $line, 2);
            next unless @values == 2;
            $sth->execute(@values);
        }
    }

  my %IDS = map { $_->[0] => 1 } @{
      $self->dbi()->dbh()->selectall_arrayref('SELECT id FROM wtf') };
  $self->{'IDS'} = \%IDS;
}


sub get_wtf
{
  my ($self, $message) = @_;

  my $session_heap = $self->client()->get_heap();
  my $last = $session_heap->{'last_math_result'};
  my $input = $message->command_input();
  my $row;

  if($input =~ m/^\s*_\s*$/) {
    $input = $last;
  }
  
  if($input !~ m/^\s*[0-9]+\s*$/) {
    @rows = $self->dbi()->select_record(
      'wtf',
      { 'acronym' => uc($input) }
    );

    my @defs = map { $_->[2] } @rows;
    my @ids = map { $_->[0] } @rows;
    my @mix;

    if(@rows > 1) {
      local $"=' | ';
      for(my $i=0; $i<scalar(@defs); $i++) {
        $mix[$i] = "$defs[$i] (id: $ids[$i])";
      }
      return $self->respond($message,
        "Found " . @mix . " definitions: @mix.");
    } elsif(@rows == 1) {
      return $self->respond($message,
        "$defs[0] (id: $ids[0])");
    }
  } else {
    $row = $self->dbi()->select_record(
      'wtf',
      { 'id' => $input }
    );
  }

  if(!$row && $input !~ m/^\s*[0-9]+\s*$/) {
    my $url = 'http://acronymfinder.com/' . $input . '.html';
    return $self->respond($message,
      "That acronym wasn't in the database, please add the"
      . " definition if you find it: $url");
  } elsif(!$row) {
    return $self->respond($message,
      "No matching acronym was found in the database.");
  }

  return $self->respond($message, "$row->{'definition'} (id: $row->{'id'})");  
}


sub add_wtf
{
  my ($self, $message) = @_;
  my $input = $message->command_input();
  my $row;

  my (@values) = split(/ /, $input, 2);
  unless(@values == 2) {
    return $self->respond($message,
      "You must have an acronym and a definition. Use !help +wtf");
  }

  my $IDS = $self->{'IDS'};
  my $id;
  my $max = (reverse sort { $a <=> $b } keys %$IDS)[0];
  foreach my $x ( 1 .. $max ) {
    unless( exists $IDS->{$x} )  {
      $id = $x; last;
    }
  }

  $id ||= $max + 1;

  $row = $self->dbi()->create_record(
    'wtf',
    { 'id'          => $id,
      'acronym'     => uc($values[0]),
      'definition'  => $values[1],
    }
  );

  $IDS->{$id} = 1;

  if(!$row) {
    return $self->respond($message,
      "There was an error adding the information.");
  }

  return $self->respond($message, "Acronym added. (id: $id)");
}


sub del_wtf
{
  my ($self,$message) = @_;
  my $id_to_del = $message->command_input();

  my $IDS = $self->{'IDS'};

  unless(defined($id_to_del)) {
    return $self->respond( $message, "Use !help -wtf" );
  }
        
  my $wtf = $self->dbi()->select_record('wtf',{'id'=>$id_to_del});

  if($wtf) {
    $self->dbi()->delete_record('wtf', $wtf);
    delete $IDS->{$id_to_del};
    return $self->respond($message, "Deleted id $id_to_del");
  } else {
    return $self->respond($message, "Acronym not found.");
    }
}


sub num_wtf
{
  my ($self,$message) = @_;
  my $count = (keys %{$self->{'IDS'}});
  my $are = $count != 1 ? 'are' : 'is';
  my $s   = $count != 1 ? 's'   : '';

  return $self->respond($message, "There $are currently $count acronym$s.");
}



1;


__DATA__
WTF [what|where|who|why|when] the [fuck|flip|frick]
WTH [what|where|who|why|when] the [hell|heck]
STFU shut the [fuck|flip|frick] up
FUBAR fucked up beyond all recognition
RTFM read the fucking manual
STFW search the fucking web
GTH go to hell
GJ good job
NT nice try
TY Thank You
WB welcome back
TYVM thank you very much
NP no problem
OMG oh my god
OMFG oh my fucking god
asl age sex location
LOL laughing out loud
ROFL rolling on the floor laughing
ROTFL rolling on the floor laughing
LMAO laughing my ass off
LMSO laughing my socks off
ROFLMAO rolling on the floor laughing my ass off
ROTFLMAO rolling on the floor laughing my ass off
ROFLMSO rolling on the floor laughing my socks off
ROTFLMSO rolling on the floor laughing my socks off
ATM at the moment
HTTP hyper-text transfer protocol
HTTPS hyper-text transfer protocol secure
WWW world wide web
FTP file transfer protocol
IRC internet relay chat
SSH secure shell
POP post office protocol
SMTP simple mail transfer protocol
IMAP internet message access protocol
DOS disk operating system
SQL structured query language
PHP php: hypertext preprocessor
XML extensible markup language
NFS network file system
IM instant message
AOL America On-Line
AIM AOL Instant Messenger
OTP on the phone
AFK away from keyboard
BRB be right back
BBIAB be back in a bit
BIAB back in a bit
BBS be back soon
BBL be back later
TTFN ta-ta for now
LTNS long time no see
CD comapct disc
DVD digital [versatile|video] disc
USB universal serial bus
PS2 personal system 2
PS2 playstation 2
PSX playstation
MS microsoft
M$ microsoft
OK okay
FF firefox
FX firefox
IE internet explorer
LAMP linux apache mysql [perl|php]
LASP linux apache sqlite [perl|php]
AWOL absent without leave
BBQ barbecue
OMGWTFBBQ oh my god what the fuck barbecue
CRT cathode ray tube
CFC chlorofluorocarbon
CNN cable news network
BBC british broadcasting corporation
ROFLMFAO rolling on the floor laughing my fucking ass off
GPA Grade Point Average
BOFH Bastard Operator From Hell
SDL Simple DirectMedia Layer
SDL Specification and Description Language
FET Field-Effect Transistor
SSR Solid State Relay
IVF In Vitro Fertilization
SCUBA Self Contained Underwater Breathing Apparatus
TV television
TV transvestite
DNA Deoxyribonucleic Acid
LSD d-Lysergic Acid Diethylamide
LSD Limited Slip Differential
LSD Least Significant Digit
VHF Very High Frequency
VLF Very Low Frequency
UHF Ultra High Frequency
UC microcontroller
POD Plain Old Documentation
POD Payment On Delivery
COD Cash On Delivery
WOW World of Warcraft
TI Texas Instrutments
POD Proof Of Delivery
NASA North American Space Agency
NOAA National Oceanic & Atmospheric Administration
EPROM Electronically Programmable Read Only Memory
EEPROM Electronically Erasable Programmable Read Only Memory
BJT Bipolar Junction Transistor
MOSFET Metal-Oxide Semiconductor Field-Effect Transistor
AFAICR as far as I can recall
AFAICT as far as I can tell
AFAIK as far as I know
AFAIR as far as I recall
AFAIU as far as I understand
JFET Junction Field Effect Transistor
AFD away from desktop
AFU all fucked up
AFW away from window
NJFET Negative-Junction Field Effect Transistor
AIU as I understand
AIUI as I understand it
PJFET Positive-Junction Field Effect Transistor
AKA also known as
ASAIC as soon as I can
VLSI Very Large-Scale Integration
ASAP as soon as possible
AWOL absent without official leave
SPICE Simulation Program With Integrated Circuit Emphasis
AYBABTU all your base are belong to us
BBT be back tomorrow
BFD big fucking deal
BIAF back in a few
FPGA Field-Programmable Gate Array
BIALW back in a little while
BIAS back in a second
BIAW back in a while
IC Integrated Circuit
BOATILAS bend over and take it like a slut
POP3 post office protocol [version] 3
BOGAHICA bend over, grab ankles, here it comes again
RC Radio Controlled
RF Radio Frequency
BOHICA bend over here it comes again
BS bullshit
BTDT been there, done that
BTTH boot to the head
CMIIW sorrect me if I'm wrong
BTW by the way
TBH to be honest
NES Nintendo Entertainment System
RC Resistor-Capacitor
CNP continued [in my] next post
DIY do it yourself
PSI Pounds per Square Inch
DKDC don't know, don't care
DSTM don't shoot the messenger
DTRT do the right thing
DTWT do the wrong thing
LC Inductor-Capacitor
DWIM do what I mean
EOF end of file
EOD end of discussion
GNOME GNU Network Object Model Environment
EWAG experienced wild-ass guess
FAQ frequently asked question
AC Alternating Current
FIIK fucked if I know
FCFS first come first served
FIGJAM fuck I'm good, just ask me
GNU GNU's Not Unix
DC Direct Current
FIIR fucked if I remember
GND Ground
FIIC fucked if I care
FOAD fuck off and die
FTFM fuck the fucking manual
FYI for your information
FWIW for what it's worth
GIGO garbage in, garbage out
FILO first in, last out
LIFO last in, first out
FIFO first in, first out
LILO last in, last out
LILO Linux Loader
GTFO get the fuck out
USA United States of America
GTG got to go
G2G got to go
GTA Grand Theft Auto
GT Gran Turismo
EA Electronic Arts
HAND have a nice day
HOPE this helps
IAC in any case
IEEE Institute of Electrical & Electronics Engineers
IIANM if I am not mistaken
ACM Association for Computing Machinery
IMHO in my humble opinion
IMHO in my honest opinion
SAE Society of Automotive Engineers
IMO in my opinion
IOW in other words
IRL in real life
LCD Liquid Crystal Display
LCD Least/Lowest Common Denominator
JK just kidding
J/K just kidding
TFT-LCD Thin Film Transistor - Liquid Crystal Display
MIA missing in action
ECU Electronic Control Unit
MYOB mind your own business
OIC oh I see
OTOH on the other hand
BFD Big Fucking Deal
OTT over the top
OT off topic
AAG Anti-Aircraft Gun
OTTOMH off the top of my head
OTL out to lunch
PEBKAC problem exists between keyboard and chair
GPU Graphics Processing/Processor Unit
PEBCAC problem exists between computer and chair
TIE Twin-Ion Engine
PFY pimply faced youth
ESD Electrostatic Discharge
RIP rest in peace
RL real life
IP internet protocol
IP in person
SFA sweet fuck all
FA fuck all
SMLSFB so many losers, so few bullets
GFY Go Fuck Yourself
GFY Good For You
SNMP simple network management protocol
SNMP sorry, not my problem
SOL shit out [of] luck
TMA too many abbreviations
TBD to be [decided|determined|done]
WIP work in progress
TOEFL test of English as a foreign language
RMS Richard M. Stallman
BOS Bend Over and Smile
RMS Root-Mean-Square
VNC virtual network connection
RDP remote desktop protocol
ESR Eric S. Raymond
DHCP dynamic host configuration protocol
WAP wireless access protocol
YKWIM you know what I mean
TIA thanks in advance
TOELF Test of English as Foreign Language
HVPS High Voltage Power Supply
__END__
