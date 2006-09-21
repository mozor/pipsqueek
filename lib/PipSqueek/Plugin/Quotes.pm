package PipSqueek::Plugin::Quotes;
use base qw(PipSqueek::Plugin);
use strict;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers(
		'multi_quote'  => 'get_quote',
		'multi_+quote' => 'add_quote',
		'multi_-quote' => 'del_quote',
		'multi_#quote' => 'cnt_quote',
		'multi_top10quotes' => 'top10_quotes',
		'public_quote++' => 'rate_quote',
		'public_quote--' => 'rate_quote',

		'pipsqueek_mergeuser' => 'pipsqueek_mergeuser',
	);

	# set up our database table
	my $schema = [
		[ 'id', 	'INTEGER PRIMARY KEY' ],
		[ 'quote',	'TEXT NOT NULL' ],
		[ 'userid',	'INT NOT NULL' ],
		[ 'created',	'TIMESTAMP NOT NULL' ],
		[ 'views',	'INT NOT NULL DEFAULT 0' ],
		[ 'rating',	'INT NOT NULL DEFAULT 0' ],
	];

	$self->dbi()->install_schema( 'quotes', $schema );

	# we store the IDs in-memory to make random retrieval faster
	my %IDS = map { $_->[0] => 1 } @{
	$self->dbi()->dbh()->selectall_arrayref( 'SELECT id FROM quotes' ) };
	$self->{'IDS'} = \%IDS;
}



#--- begin irc handlers ---#
sub top10_quotes
{
	my ($self,$message) = @_;
	my $IDS = $self->{'IDS'};

	unless( keys %$IDS )
	{
		$self->respond( $message, "There are no quotes." );
		return;
	}

	my $dbh = $self->dbi()->dbh();
	my $sth = $dbh->prepare( 
		"SELECT * FROM quotes ORDER BY rating DESC LIMIT 10"
		  );
	   $sth->execute();
	
	my @top3;
	my @rest;
	
	while( my $row = $sth->fetchrow_hashref('NAME_lc') )
	{
		my $sample = substr($row->{'quote'},0,200);
		   $sample .= "..." unless length($sample) < 200;
		
		if( @top3 < 3 )
		{
			push(@top3, '#' . (@top3+1) . qq(, id $row->{'id'}: $sample));
		}
		else
		{
			push(@rest,$row->{'id'});
		}
	}

	foreach my $text ( @top3 )
	{
		$self->respond( $message, $text );
	}
	
	local $" = ', ' if @rest > 2;#"
	$rest[$#rest] = "and $rest[$#rest]" if @rest > 1;
	my $s = @rest == 1 ? '' : 's';
	my $w = @rest == 1 ? 'is' : 'are';

	if( @rest )
	{
		$self->respond( $message, "And the runner$s up $w id$s: @rest" );
	}
}


sub get_quote
{
	my ($self,$message) = @_;
	my $pattern_or_id = $message->command_input();

	my $dbi = $self->dbi();
	my %IDS = %{$self->{'IDS'}};

	unless( keys %IDS )
	{
		$self->respond( $message, "There are no quotes." );
		return;
	}

	$pattern_or_id =~ s/^\s+//gi;
	$pattern_or_id =~ s/\s+$//gi;
	
	my @rows;

	# plain old !quote gets a random one
	unless( defined $pattern_or_id && $pattern_or_id ne "" )
	{
		my @IDS = keys %IDS;
		$pattern_or_id = @IDS[rand @IDS];
	}

	# pick a random quote according to rating heuristic
	if( $pattern_or_id =~ m/!(r)?([><=])(\d+)/ )
	{
		my ($r,$c,$x) = ($1,$2,$3);
		@rows = $dbi->select_record( 'quotes', {
					'rating' => [ $c, $x ]
				} );
		if( $r ) {
			$pattern_or_id = (@rows[rand @rows])->[0];
		}
	}

	# searching for a quote by id
	if( $pattern_or_id =~ /^\d+$/ || $pattern_or_id eq '_' )
	{
		if( $pattern_or_id eq '_' ) 
		{
			my $heap = $self->client()->get_heap();
			$pattern_or_id = int($heap->{'last_math_result'});
		}

		my $quote = $dbi->select_record( 'quotes', { 
					'id' => $pattern_or_id
				} );

		unless( defined($quote) )
		{
			$self->respond( $message, "Quote not found." );
			return;
		}

		$quote->{'views'}++;
		$self->dbi()->update_record( 'quotes', $quote );

		$self->respond( $message, 
			sprintf( "%s (id: %d, views: %d, rating: %d)",
				 $quote->{'quote'}, $quote->{'id'},
				 $quote->{'views'}, $quote->{'rating'} ) );
		return;
	}
	# searching for a quote by regex
	else
	{
		@rows = $dbi->select_record( 'quotes', {
			'quote' => [ 'LIKE', "\%$pattern_or_id\%" ] 
			} ) unless @rows;

		if( @rows > 1 )
		{
			my @ids = map { $_->[0] } @rows;
			my $max = 0;
			if( @ids >= 50 ) { $max = 1; @ids = @ids[0 .. 49] }

			local $"=', ';#"
			$self->respond( $message,
				"Found " . ($max ? 'more than 50' : @ids) . " matching ids" . ($max ? ' (first 50)' : '') . ": @ids." );

			return;
		}
		elsif( @rows == 1 )
		{
			my $q_arr = $rows[0];

			$self->dbi()->update_record( 'quotes', 
				$q_arr->[0], { 'views' => $q_arr->[4]+1 } );
		
			$self->respond( $message, 
			sprintf( "%s (id: %d, views: %d, rating: %d)",
				 $q_arr->[1], $q_arr->[0],
				 $q_arr->[4], $q_arr->[5] ) );
			return;
		}
		else
		{
			$self->respond( $message, "No matches found." );
			return;
		}
	}
}


sub add_quote
{
	my ($self,$message) = @_;
	my $quote = $message->command_input();

	unless( defined($quote) ) 
	{
		$self->respond( $message, "Use !help +quote" );
		return;
	}

	my $IDS = $self->{'IDS'};

	# go back and fill in gaps in the quote sequence
	my $id;
	my $max = (reverse sort { $a <=> $b } keys %$IDS)[0];
	foreach my $x ( 1 .. $max ) {
		unless( exists $IDS->{$x} )  {
			$id = $x; last;
		}
	}
	$id ||= $max+1;


	my $uid = $self->search_or_create_user( $message )->{'id'};

	$self->dbi()->create_record( 'quotes', {
		'id' => $id,
		'quote' => $quote,
		'userid' => $uid,
		'created' => time()
	} );

	$IDS->{$id} = 1;

	$self->respond( $message, "Quote added. (id: $id)" );
	return;
}


sub del_quote
{
	my ($self,$message) = @_;
	my $id_to_del = $message->command_input();

	my $IDS = $self->{'IDS'};

	unless( defined($id_to_del) )
	{
		$self->respond( $message, "Use !help -quote" );
		return;
	}
		
	my $quote = $self->dbi()->select_record( 'quotes',{'id'=>$id_to_del} );

	if( $quote )
	{
		$self->dbi()->delete_record( 'quotes', $quote );
		delete $IDS->{$id_to_del};
		$self->respond( $message, "Deleted quote $id_to_del" );
	}
	else
	{
		$self->respond( $message, "Quote not found." );
		return;
	}
}

sub rate_quote
{
	my ($self,$message) = @_;
	my $id_to_rate = $message->command_input();
	my $event = $message->event();

	unless( defined($id_to_rate) )
	{
		$self->respond( $message, "Use !help $event" );
		return;
	}

	my $quote = $self->dbi()->select_record('quotes',{'id'=>$id_to_rate});

	if( $quote )
	{
		$event eq 'public_quote++' 
			? $quote->{'rating'}++ 
			: $quote->{'rating'}--;

		$self->dbi()->update_record( 'quotes', $quote );
	}
	else
	{
		$self->respond( $message, "Quote not found." );
		return;
	}
}


sub cnt_quote
{
	my ($self,$message) = @_;

	my $count = (keys %{$self->{'IDS'}});
	my $are = $count != 1 ? 'are' : 'is';
	my $s   = $count != 1 ? 's'   : '';

	$self->respond( $message, "There $are currently $count quote$s." );
	return;
}


sub pipsqueek_mergeuser
{
	my ($self,$message,$user1,$user2) = @_;

	my $sql = 'UPDATE quotes SET userid=? WHERE userid=?';
	my $sth = $self->dbi()->dbh()->prepare( $sql );
	   $sth->execute( $user1->{'id'}, $user2->{'id'} );
}


1;


__END__
