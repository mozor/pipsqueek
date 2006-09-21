package PipSqueek::Plugin::WTF;
use base qw(PipSqueek::Plugin);
use strict;

sub plugin_initialize
{
    (shift)->plugin_handlers({
        'multi_wtf'     => 'multi_wtf',
        'multi_acronym' => 'multi_wtf',
    });
}


sub multi_wtf
{
    my ($self,$message) = @_;
    my $stuff = $message->command_input();
    $stuff = 'RTFM' unless defined $stuff && length $stuff;
    $stuff =~ s/^\s*(?:is\s+)?(.+)$/$1/i;
    $stuff = uc $stuff;
    $stuff =~ s/\s*\??\s*$//;

    my $response = $self->find_wtf($stuff);

    if (defined $response) {
        $response = "${stuff}: $response";
    } else {
        $response = "Gee...  I don't know what $stuff means...";
    }
    $self->respond($message, $response);
}


sub find_wtf
{
    my $self = shift;
    my $acronym = uc shift;

    my @rv = ();
    while (defined (my $line = <DATA>)) {
        chomp $line;
        if ($line =~ /^(\S+)\s+(.*)$/ && $1 eq $acronym) 
        {
			my $find = $2;
            push(@rv,$find);
        }
    }

    return scalar(@rv) == 0 ? undef : join(', ',@rv);
}


1;


__DATA__
AFAICR	as far as I can recall
AFAICT	as far as I can tell
AFAIK	as far as I know
AFAIR	as far as I recall
AFAIU	as far as I understand
AFD	away from desktop
AFK	away from keyboard
AFU	all fucked up
AFW	away from window
AIU	as I understand
AIUI	as I understand it
AKA	also known as
ASAIC	as soon as I can
ASAP	as soon as possible
ATM	at the moment
AWOL	absent without official leave
AYBABTU	all your base are belong to us
B/C	because
B/S	bullshit
B/W	between
BBIAB	be back in a bit
BBL	[I'll] be back later
BBS	be back soon
BBT	be back tomorrow
BFD	big fucking deal
BIAB	back in a bit
BIAF	back in a few
BIALW	back in a little while
BIAS	back in a second
BIAW	back in a while
BOATILAS	bend over and take it like a slut
BOFH	bastard operator from hell
BOGAHICA	bend over, grab ankles, here it comes again
BOHICA	bend over here it comes again
BRB	[I'll] be right back
BS	bullshit
BTDT	been there, done that
BTTH	boot to the head
BTW	by the way
CMIIW	correct me if I'm wrong
CNP	continued [in my] next post
COB	close of business [day]
CYA	see you around
D/L	download
DIY	do it yourself
DKDC	don't know, don't care
DSTM	don't shoot the messenger
DTRT	do the right thing
DTWT	do the wrong thing
DWIM	do what I mean
EG	evil grin
EMSG	email message
EOB	end of business [day]
EOD	end of discussion
EOL	end of life
ETLA	extended three letter acronym
EWAG	experienced wild-ass guess
FAQ	frequently asked question
FCFS	first come first served
FIGJAM	fuck I'm good, just ask me
FIIK	fuck[ed] if I know
FIIR	fuck[ed] if I remember
FM	fucking magic
FOAD	fall over and die
FSDO	for some definition of
FSVO	for some value of
FTFM	fuck the fuckin' manual!
FUBAR	fucked up beyond all recognition
FUD	fear, uncertainty and doubt
FWIW	for what it's worth
FYI	for your information
G	grin
G/C	garbage collect
GAC	get a clue
GAL	get a life
GIGO	garbage in, garbage out
GMTA	great minds think alike
GTFO	get the fuck out
GTG	got to go
HAND	have a nice day
HHIS	hanging head in shame
HICA	here it comes again
HTH	hope this helps
I18N	internationalization
IAC	in any case
IANAL	I am not a lawyer
IC	I see
ICBW	I could be wrong
ICCL	I couldn't care less
IHAFC	I haven't a fucking clue
IHBW	I have been wrong
IHNFC	I have no fucking clue
IIANM	if I am not mistaken
IIRC	if I recall correctly
IIUC	if I understand correctly
IMAO	in my arrogant opinion
IMCO	in my considered opinion
IMHO	in my humble opinion
IMNSHO	in my not so humble opinion
IMO	in my opinion
IOW	in other words
IRL	in real life
ISAGN	I see a great need
ISTM	it seems to me
ISTR	I seem to recall
ITYM	I think you mean
IYSS	if you say so
IWBNI	it would be nice if
J/K	just kidding
JIC	just in case
JK	just kidding
JMO	just my opinion
JTLYK	just to let you know
KISS	keep it simple, stupid
KITA	kick in the ass
KNF	kernel normal form
L8R	later
LART	luser attitude readjustment tool (ie, hammer)
LJBF	let's just be friends
LMAO	laughing my ass off
LMFAO	laughing my fucking ass off
LMSO	laughing my socks off
LMFSO	laughing my fucking socks off
LOL	laughing out loud
LTNS	long time no see
MIA	missing in action
MOTAS	member of the appropriate sex
MOTOS	member of the opposite sex
MOTSS	member of the same sex
MTF	more to follow
MYOB	mind your own business
N/M	never mind
NBD	no big deal
NFC	no fucking clue
NFI	no fucking idea
NFW	no fucking way
NIH	not invented here
NMF	not my fault
NMP	not my problem
NOYB	none of your business
NOYFB	none of your fucking business
NP	no problem
NRFPT	not ready for prime time
NRN	no reply necessary
OIC	oh, I see
OMG	oh, my god
OT	off topic
OTL	out to lunch
OTOH	on the other hand
OTT	over the top
OTTOMH	off the top of my head
PEBKAC	problem exists between keyboard and chair
PFO	please fuck off
PFY	pimply faced youth
PITA	pain in the ass
PKSP	pound keys and spew profanity
PNG	persona non grata
PNP	plug and pray
POC	point of contact
POLA	principle of least astonishment
POS	piece of shit
PPL	pretty please
PTV	parental tunnel vision
QED	quod erat demonstrandum
RFC	request for comments
RIP	rest in peace
RL	real life
RLC	rod length check
ROFL	rolling on floor laughing
ROFLMAO	rolling on floor laughing my ass off
ROFLMFAO	rolling on floor laughing my fucking ass off
ROTFL	rolling on the floor laughing
ROTFLMAO	rolling on the floor laughing my ass off
ROTFLMFAO	rolling on the floor laughing my fucking ass off
RP	responsible person
RSN	real soon now
RTFB	read the fine/fucking book
RTFC	read the fine/fucking code
RTFD	read the fine/fucking documentation
RTFM	read the fine/fucking manual
RTFMP	read the fine/fucking man page
RTFS	read the fine/fucking source
SCNR	sorry, could not resist
SEP	someone else's problem
SFA	sweet fuck all
SHID	slaps head in disgust
SIMCA	sitting in my chair amused
SMLSFB	so many losers, so few bullets
SMOP	simple matter of programming
SNAFU	situation normal, all fucked up
SNERT	snot-nosed egotistical rude teenager
SNMP	sorry, not my problem
SNR	signal to noise ratio
SO	significant other
SOB	son of [a] bitch
SOL	shit out [of] luck
SOP	standard operating procedure
SSIA	subject says it all
STFA	search the fucking archives
STFU	shut the fuck up
SUS	stupid user syndrome
SWAG	silly, wild-assed guess
SWAHBI	silly, wild-assed hare-brained idea
SWMBO	she who must be obeyed
TANSTAAFL	there ain't no such thing as a free lunch
TBC	to be continued
TBD	to be {decided,determined,done}
TBOMK	the best of my knowledge
THNX	thanks
THX	thanks
TIA	thanks in advance
TINC	there is no cabal
TLA	three letter acronym
TLB	translation lookaside buffer
TMA	too many abbreviations
TMI	too much information
TOEFL	test of english as a foreign language
TRT	the right thing
TTBOMK	to the best of my knowledge
TTFN	ta ta for now
TTYL	talk to you later
TWIAVBP	the world is a very big place
TY	thank you
TYVM	thank you very much
U/L	upload
UTSL	use the source, Luke
VEG	very evil grin
W/	with
W/O	without
WAG	wild-ass guess
WB	welcome back
WFM	works for me
WIBNI	wouldn't it be nice if
WIP	work in progress
WOFTAM	waste of fucking time and money
WOMBAT	waste of money, brain, and time
WRT	with respect to
WTF	{what,where,who,why} the fuck
WTH	{what,where,who,why} the hell
WYSIWYG	what you see is what you get
YALIMO	you are lame, in my opinion
YHBT	you have been trolled
YHL	you have lost
YKWIM	you know what I mean
YMA	yo momma's ass
YMMV	your mileage may vary
YW	you're welcome
ABI	application binary interface
ACPI	advanced configuration and power interface
ADC	analog [to] digital converter
AGP	accelerated graphics port
ANSI	american national standards institute
API	application programming interface
APIC	advanced programmable interrupt controller
ARP	address resolution protocol
AT	advanced technology
ATA	advanced technology attachment
ATAPI	advanced technology attachment packet interface
ATM	asynchronous transfer mode
ATX	advanced technology extended
BEDO	burst extended data output
BGP	border gateway protocol
BIOS	basic input/output system
BLOB	binary large object
BSD	berkeley software distribution
CAD	computer-aided design
CAV	constant angular velocity (as opposed to CLV)
CD	compact disc
CDRAM	cache dynamic random access memory
CGA	color graphics array
CGI	common gateway interface
CHS	cylinder/head/sector
CIDR	classless inter-domain routing
CLI	command line interface
CLV	constant linear velocity (as opposed to CAV)
COFF	common object file format
CPU	central processing unit
CRLF	carriage return line feed
CRT	cathode ray tube
CSS	cascading style sheets
CVS	concurrent versions system
DAC	digital [to] analog converter
DDC	display data channel
DDR	double data rate
DDWG	digital display working group
DHCP	dynamic host configuration protocol
DMA	direct memory access
DNS	domain name system
DRAM	dynamic random access memory
DSL	digital subscriber line
DTD	document type definition
DVD	digital versatile disc
DVI	digital visual interface
ECP	enhanced capability port
EDID	extended display identification data
EDO	extended data out
EEPROM	electrically erasable programmable read only memory
EGA	enhanced graphics array
EISA	extended industry standard architecture
ELF	executable and linking format
EPP	enhanced parallel port
EPROM	erasable programmable read only memory
ESDRAM	enhanced synchronous dynamic random access memory
FAT	file allocation table
FBRAM	frame buffer random access memory
FDDI	fiber distributed data interface
FFS	fast file system
FLOPS	floating [point] operations per second
FPM	fast page mode
FQDN	fully qualified domain name
FTP	file transfer protocol
GIF	graphics interchange format
GNU	gnu's not unix
GPL	gnu/general public license
GPU	graphics processing unit
GUI	graphics user interface
HDCP	high-bandwidth digital content protection
HTML	hyper-text markup language
HTTP	hyper-text transfer protocol
I2O	intelligent input/output
IANA	internet assigned number authority
IC	integrated circuit
ICB	internet citizen's band
ICMP	internet control message protocol
IDE	integrated drive electronics
IEC	international electrotechnical commission
IEEE	institute [of] electrical [and] electronics engineers
IESG	internet engineering steering group
IETF	internet engineering task force
IKE	internet key exchange
IMAP	internet mail access protocol
INCITS	international committee on information technology standards
IO	input/output
IOCTL	input/output control
IP	internet protocol
IPNG	internet protocol, next generation
IPSEC	internet protocol security
IRC	internet relay chat
IRQ	interrupt request
IRTF	internet research task force
ISA	industry standard architecture
ISDN	integrated services digital network
ISO	international standards organization
ISOC	internet society
ISP	internet service provider
JPEG	joint photographic experts group
KVA	kernel virtual address
LAN	local area network
LBA	logical block addressing
LCD	liquid crystal display
LDAP	lightweight directory access protocol
LED	light emitting diode
LIR	local internet registry
LSB	least significant bit [or: byte]
LUN	logical unit number
MAC	media access control
MBR	master boot record
MDRAM	multibank dynamic random access memory
MIDI	musical instrument digital interface
MIME	multipurpose internet mail extensions
MIPS	million instructions per second
MMU	memory management unit
MPEG	moving picture experts group
MSB	most significant bit [or: byte]
MTA	mail transfer agent
MTU	maximum transmission unit
MUA	mail user agent
NAT	network address translation
NFS	network file system
NIC	network interface card
NIS	network information service
NUMA	non uniform memory access
OEM	original equipment manufacturer
OSF	open software foundation
OSI	open systems interconnection
OTP	one time password
PAM	pluggable authentication modules
PAX	portable archive exchange
PCI	peripheral component interconnect
PCMCIA	personal computer memory card international association
PDP	page descriptor page
PERL	practical extraction [and] report language
PGP	pretty good privacy
PIC	programmable interrupt controller
PID	process id
PIO	programmed input/output
PNG	portable network graphics
POP	post office protocol
POSIX	portable operating system interface [for] unix
POST	power on self test
PPP	point-to-point protocol
PPPOA	point-to-point protocol over ATM
PPPOE	point-to-point protocol over ethernet
PROM	programmable read only memory
PTE	page table entry
PTLA	pseudo top level aggregator
PTP	page table page
RAID	redundant array of inexpensive disks
RAM	random access memory
RCS	revision control system
RFC	request for comments
RGB	red green blue
RISC	reduced instruction set computing
ROM	read only memory
RPM	revolutions per minute
RTF	rich text format
S/PDIF	sony/phillips digital interface
SACD	super audio compact disc
SAM	serial access memory
SASI	shugart associates system interface (predecessor to SCSI)
SATA	serial advanced technology attachment
SCSI	small computer system interface
SDRAM	synchronous dynamic random access memory
SGRAM	synchronous graphics random access memory
SLDRAM	synchronous-link dynamic random access memory
SMART	self-monitoring analysis and reporting technology
SMP	symmetric multiprocessing
SMTP	simple mail transfer protocol
SNMP	simple network management protocol
SPD	serial presence detect
SRAM	static random access memory
SSH	secure shell
SSL	secure sockets layer
STP	shielded twisted pair
SVGA	super video graphics array
TCL	tool command language
TCP	transmission control protocol
TFT	thin film transistor
TIFF	tagged image file format
TLA	top level aggregator
TLB	transition lookaside buffer
TLD	top level domain
TMDS	transition minimized differential signaling
TTY	teletype
TZ	time zone
UC	uncacheable
UDP	user datagram protocol
UPS	uninterruptible power supply
URI	uniform resource identifier
URL	uniform resource locator
USB	universal serial bus
USWC	uncacheable speculative write combining
UTP	unshielded twisted pair
UUCP	unix-to-unix copy protocol
VAX	virtual address extension
VCM	virtual channel memory
VESA	video electronics standards association
VGA	video graphics array
VM	virtual memory
VPN	virtual private network
VRAM	video random access memory
WAN	wide area network
WAP	wireless application protocol
WRAM	window random access memory
WWW	world wide web
XGA	extended graphics array
XML	extensible markup language
XSL	extensible stylesheet language
XT	extended technology
