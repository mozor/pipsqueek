package PipSqueek::Jabber_Client;
use base 'Class::Accessor::Fast';
use strict;
use utf8;
use Encode qw();

use POE; 									#include POE constants
use POE::Component::Jabber; 				#include PCJ
use POE::Component::Jabber::Error; 			#include error constants
use POE::Component::Jabber::Status; 			#include status constants
use POE::Component::Jabber::ProtocolFactory;		#include connection type constants
use POE::Filter::XML::Node; 				#include to build nodes
use POE::Filter::XML::NS qw/ :JABBER :IQ /; 		#include namespace constants
use POE::Filter::XML::Utils; 				#include some general utilites
use Carp;

use Filter::Template; 					#this is only a shortcut
use FindBin qw($Bin);
use File::Spec::Functions;
use File::Find;
const XNode POE::Filter::XML::Node

use PipSqueek::Jabber_Message;
use PipSqueek::Plugin;
use PipSqueek::DBI;
use PipSqueek::Config;
use POE::Filter::XML::Utils;

sub new {
 my $proto = shift;
 my $class = ref($proto) || $proto;
 my $self  = bless( {}, $class );
 
 $self->mk_accessors('SESSION_ID', 'SESSION', 'CONFIG', 'PLUGINS', 'BASEPATH', 'ROOTPATH', 'ALLOWED_PLUGINS', 'REGISTRY','CONFIG','DBI','JABBER_CLIENT_ALIAS');
 $self->PLUGINS({});
 $self->REGISTRY({});
 $self->BASEPATH(shift);
 $self->ROOTPATH(catdir( $Bin, '../'));
 if (!$self->BASEPATH()) {$self->BASEPATH($self->ROOTPATH());}
 
 my $datafile = catfile( $self->BASEPATH(), '/var/pipsqueek.db' );
 my $dbi = PipSqueek::DBI->new(
            "DBI:SQLite:$datafile",
            { 'RaiseError' => 1, 'AutoCommit' => 1 } 
            );
 $self->DBI( $dbi );
 my $config = PipSqueek::Config->new($self->ROOTPATH(),$self->BASEPATH());
 my $c_data = {
        'enable_jabber_session'	=> '0',
        'jabber_server_address'    => 'talk.google.com',
        'jabber_server_port'        => '5222',
        'jabber_password'    => '',
        'jabber_nickname'    => '',
        'jabber_hostname'    => 'gmail.com',
        'jabber_tls_enable'	=> '1',
        'allowed_plugins'	=> '',
        'automatically_subscribe'	=> '1',
    };

 $config->load_config( undef, $c_data );
 $config->load_config( '/etc/pipsqueek_jabber.conf' );
 my @allowed_plugins=split(/,|\s+|,\s+/,$config->allowed_plugins);
 $self->ALLOWED_PLUGINS(\@allowed_plugins);
 if ($config->enable_jabber_session() ne "1") {return;}
 $self->CONFIG( $config );
 $self->SESSION_ID($self->_create_session()->ID());
 return $self;
 }

sub _create_session {
 my ($self)=@_;
 return POE::Session->create(
	options => { debug => 1, trace => 1},
	heap => {'whoami'=>'Jabber'},
	inline_states => {
		_stop =>
			sub
			{
				my $kernel = $_[KERNEL];
				$kernel->alias_remove();
			},
		},
	object_states => [$self => ['_start', 'input_event', 'error_event', 'status_event', 'output_event', 'plugins_load', 'plugins_wipe', 'plugin_delegate', 'plugin_unregister', 'send_presence', 'add_to_roster', 'remove_from_roster', 'roster_request', 'roster_return']]
	);
 }

sub _start {
 my ($kernel, $heap, $self) = @_[KERNEL, HEAP, OBJECT];
 my $c=$self->CONFIG();
 $kernel->alias_set('Tester');
 $heap->{'whoami'}="Jabber";
 $heap->{'component'} = 
	POE::Component::Jabber->new(
		IP => $c->jabber_server_address(),
		Port => $c->jabber_server_port(),
		Hostname => $c->jabber_hostname(),
		Username => $c->jabber_nickname(),
		Password => $c->jabber_password(),
		Alias => 'COMPONENT',

		ConnectionType => ($c->jabber_tls_enable() ? +XMPP : +LEGACY),
		Debug => '1',

		States => {
			StatusEvent => 'status_event',
			InputEvent => 'input_event',
			ErrorEvent => 'error_event',
			}
		);
 $kernel->post('COMPONENT', 'connect');
 }

sub session_connect {}

sub session_disconnect {
 my ($self,$kernel,$message) = @_[OBJECT, KERNEL, ARG0];
 $kernel->post($self->JABBER_CLIENT_ALIAS(), 'shutdown');
 return 1;
 }

sub status_event() {
 my ($kernel, $sender, $heap, $state, $self) = @_[KERNEL, SENDER, HEAP, ARG0, OBJECT];

 if($state == +PCJ_INIT_FINISHED) {
  my $jid = $heap->{'component'}->jid();
  print "INIT FINISHED! \n";
  print "JID: $jid \n";
  print "SID [JABBER_CLIENT_ALIAS]: ",$sender->ID()," \n\n";

  $heap->{'jid'} = $jid;
  $heap->{'sid'} = $sender->ID();
  $self->JABBER_CLIENT_ALIAS($sender->ID());	#another: COMPONENT
  $self->SESSION_ID('Tester');

  $kernel->post($self->JABBER_CLIENT_ALIAS(), 'output_handler', XNode->new('presence'));
  $kernel->post($self->JABBER_CLIENT_ALIAS(), 'purge_queue');

  $kernel->yield('roster_request');
  }

 print "Status received: $state \n";
 }

sub roster_request() {
 my ($self) = $_[OBJECT];
 my $node = XNode->new('iq');
 $node->attr('type', 'get');
 $node->insert_tag('query', ['xmlns', +NS_JABBER_ROSTER]);
 $self->kernel->post($self->JABBER_CLIENT_ALIAS(), 'return_to_sender', 'roster_return', $node);
 }

sub roster_return() {
 my ($heap, $node, $kernel) = @_[HEAP, ARG0, KERNEL];
 my @items = $node->get_tag('query')->get_tag('item');
 foreach my $item (@items) {
  next unless defined $item;
  $heap->{'roster'}->{$item->attr('jid')}=$item->attr('subscription');
  }
 use Data::Dumper; print Dumper $heap->{'roster'};
 }

sub send_presence() {
 my ($self,$jid,$type)=@_[OBJECT,ARG0,ARG1];
 my $node=XNode->new('presence');
 $node->attr('to',$jid );
 $node->attr('type',$type) if $type;
 $self->kernel->post($self->JABBER_CLIENT_ALIAS(), 'output_handler',$node);
 }

sub add_to_roster {
 my ($self,$jid)=@_[OBJECT,ARG0];
 my $respond = XNode->new('iq');
 $respond->insert_attrs(['id', 'push', 'type', +IQ_SET]);
 $respond->insert_tag('query')->attr('xmlns',+NS_JABBER_ROSTER);
 $respond->get_tag('query')->insert_tag('item')->insert_attrs(['jid',$jid,'name',$jid]);
 $self->kernel->post($self->JABBER_CLIENT_ALIAS(), 'output_handler', $respond);

 my $respond = XNode->new('presence');
 $respond->insert_attrs(['to', $jid, 'type', 'subscribe']);
 $self->kernel->post($self->JABBER_CLIENT_ALIAS(), 'output_handler', $respond);
 }

sub remove_from_roster {
 my ($self,$jid)=@_[OBJECT,ARG0];
 my $respond = XNode->new('iq');
 $respond->insert_attrs(['type', +IQ_SET, 'id', 'push']);
 $respond->insert_tag('query')->attr('xmlns',+NS_JABBER_ROSTER);
 $respond->get_tag('query')->insert_tag('item')->insert_attrs(['jid',$jid,'subscription','remove']);
 $self->kernel->post($self->JABBER_CLIENT_ALIAS(), 'output_handler', $respond);
 }

sub input_event() {
 my ($kernel, $heap, $node, $self) = @_[KERNEL, HEAP, ARG0, OBJECT];

 print "\n===PACKET RECEIVED===\n";
 print $node->to_str() . "\n";
 print "=====================\n\n";

 my $type=$node->attr('type');
 if ($self->CONFIG()->automatically_subscribe() and $node->name=~/^presence$/i and $type=~/^subscribe$/i) {
  print "ASK FOR SUBSCRIBTION FROM ".$node->attr('from')."\n";
  $self->kernel->yield('send_presence', $node->attr('from'), 'subscribed');
  $self->kernel->yield('add_to_roster',$node->attr('from'));
  $self->kernel->yield('roster_request');
  }

 elsif ($node->name=~/^presence$/i and $type=~/^unsubscribed$/i) {
  $self->kernel->yield('send_presence', $node->attr('from'), 'unsubscribed');
  delete($heap->{'roster'}->{$node->attr('from')});
  $self->kernel->yield('remove_from_roster',$node->attr('from'));
  }

 elsif ($node->name=~/^message$/i) {
  my $jm=PipSqueek::Jabber_Message->new($node);
  if ($jm) {
   $self->plugin_delegate($jm);
   }
  }
 }

sub respond() {
 my ($self,$message,$output)=@_;
 my $heap=$self->get_heap();

 print "\n\n=====================\n\n";
 print "Nick to = ", $self->JABBER_CLIENT_ALIAS()." & ".$heap->{'sid'} . "\n";
 print "\n\n=====================\n\n";

 my $node = XNode->new('message');
 my $sender= (ref($message) ? $message->sender() : $message);
 $node->attr('to', $sender);
 $node->attr('type', 'chat');
 Encode::_utf8_on($output);
 $node->insert_tag('body')->data($output);
 print $node->to_str() . "\n";
 $self->kernel->post($self->JABBER_CLIENT_ALIAS(), 'output_handler', $node);
 return 1;
 }

sub privmsg() {return (shift)->respond(@_);}
sub respond_act { return (shift)->respond(@_); }
sub respond_user { return (shift)->respond(@_); }

sub output_event()
{
	my ($kernel, $heap, $node, $sid) = @_[KERNEL, HEAP, ARG0, ARG1];
	
	print "\n===PACKET SENT===\n";
	print $node->to_str() . "\n";
	print "=================\n\n";
	print $node->to_str(),"\n";
	
	$kernel->post($sid, 'output_handler', $node);
}

sub error_event()
{
	my ($kernel, $sender, $heap, $error) = @_[KERNEL, SENDER, HEAP, ARG0];

	if($error == +PCJ_SOCKETFAIL)
	{
		my ($call, $code, $err) = @_[ARG1..ARG3];
		print "Socket error: $call, $code, $err\n";
		print "Reconnecting!\n";
		$kernel->post($sender, 'reconnect');
	
	} elsif($error == +PCJ_SOCKETDISCONNECT) {
		
		print "We got disconneted\n";
		print "Reconnecting!\n";
		$kernel->post($sender, 'reconnect');
	
	} elsif($error == +PCJ_CONNECTFAIL) {

		print "Connect failed\n";
		print "Retrying connection!\n";
		$kernel->post($sender, 'reconnect');
	
	} elsif ($error == +PCJ_SSLFAIL) {

		print "TLS/SSL negotiation failed\n";

	} elsif ($error == +PCJ_AUTHFAIL) {

		print "Failed to authenticate\n";

	} elsif ($error == +PCJ_BINDFAIL) {

		print "Failed to bind a resource\n";
	
	} elsif ($error == +PCJ_SESSIONFAIL) {

		print "Failed to establish a session\n";
	}
}

# this lets us access the heap for our current session
sub get_heap {
 return $poe_kernel->get_active_session()->get_heap();
 }

# this lets us post events to the kernel from outside ourselves
sub post {
 my $self = shift;
 $poe_kernel->post( @_ );
 }

# this lets us post events to our own session from outside ourselves
sub yield {
 my $self = shift;
 $poe_kernel->post( $self->SESSION_ID(), @_ );
 }

# this lets other objects access the poe kernel without having to 'use POE'
sub kernel {return $poe_kernel;}

sub plugins_load {
 my ($self,$kernel) = @_[OBJECT, KERNEL];
 print "LOADING JABBER PLUGINS...\n";
 $self->kernel()->call( $self->SESSION_ID(), 'plugins_wipe' );
 my $plugins = $self->PLUGINS();
 my $config  = $self->CONFIG();

 find({ 'wanted' => 
    sub {
        $_ =~ s|^.*/||;
        return if /^\./ or $_ !~ /\.pm$/;
        return if $File::Find::name =~ /CVS/;
        return if $File::Find::dir !~ /Plugin$/;
        s/\.pm$//;
        
        $File::Find::name =~ s/bin\/..\///;

        my $module = "PipSqueek::Plugin::$_";
		my $name=$_;
        return if exists $plugins->{$module};

        if (grep {$_ eq $name} @{$self->ALLOWED_PLUGINS}) {
            delete $INC{$File::Find::name}; # unload
            require $File::Find::name;      # reload 

            # create new instance and initialize it
            my $plugin = $module->new( $self ); 

            $plugin->config_initialize();    # initialize config
            $config->load_config( $plugin );
    
            $plugin->plugin_initialize();  # initialize plugin

            $plugins->{$module} = $plugin; # store in registry	
  	    my $registry = $self->REGISTRY();
	    my $handlers = $plugin->plugin_handlers();
	    while( my ($event,$method) = each %$handlers ) {
		my $metadata = {'obj' => $plugin, 'sub' => $method};
		push( @{ $registry->{$event} }, $metadata );
		}
            1;
        };

        warn "Failed to load $module: $@\n" if $@;

    }, 'no_chdir' => 1, },
    catdir( $self->BASEPATH(), 'lib/PipSqueek/Plugin' ),
    catdir( $self->ROOTPATH(), 'lib/PipSqueek/Plugin' ),
    );
 return 1;
 }

sub plugin_register {
 my ($self,$plugin) = @_[OBJECT, ARG0];

 my $registry = $self->REGISTRY();
 my $handlers = $plugin->plugin_handlers();

 while( my ($event,$method) = each %$handlers ) {
  my $metadata = {'obj' => $plugin, 'sub' => $method};
  push( @{ $registry->{$event} }, $metadata );
  }

 return 1;
 }

sub plugin_unregister {
 my ($self,$plugin) = @_[OBJECT, ARG0];

 my $registry = $self->REGISTRY();
 my $handlers = $plugin->plugin_handlers();

 while( my ($event,$method) = each %$handlers ) {
  my $r_events = $registry->{$event};
  my @x_delete = ();

  foreach my $x ( 0 .. $#$r_events ) {
   my $meta = $r_events->[$x];
   if (ref($meta->{'obj'}) eq ref($plugin) && $meta->{'sub'} eq $method ) {
    push(@x_delete,$x);
    }
   }

  foreach my $x ( @x_delete ) {
   delete $registry->{$event}->[$x];
   }
  }

 return 1;
 }

sub plugins_wipe {
 my ($self,$kernel) = @_[OBJECT, KERNEL];

 my $plugins = $self->PLUGINS();

 foreach my $plugin ( keys %$plugins ) {
  $kernel->call( $self->SESSION_ID(), 'plugin_unregister', $plugins->{$plugin} );
  $plugins->{$plugin}->plugin_teardown();
  }

 $self->PLUGINS({});
 }

sub plugin_delegate {
 my ($self,$message) = @_;
 my $registry = $self->REGISTRY();
 if (!%$registry) {print "1"; $self->plugins_load();}
 my $event=$message->command();
	
 if (exists($registry->{"public_$event"})) {$event="public_$event";}
 elsif (exists($registry->{"private_$event"})) {$event="private_$event";}
 elsif (exists($registry->{"multi_$event"})) {$event="multi_$event";}
 elsif (!exists($registry->{$event})) {return 0;}
 # call the handlers
 foreach my $metaobject ( @{ $registry->{$event} } ) {
  my $plugin = $metaobject->{'obj'};
  my $method = $metaobject->{'sub'};

  if ($plugin->can($method)) { $plugin->$method($message); }

  }
 return 1;
 }

1;
