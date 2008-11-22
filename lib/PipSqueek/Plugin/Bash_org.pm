package PipSqueek::Plugin::Bash_org;
use base qw(PipSqueek::Plugin);

sub plugin_initialize
{
    my $self = shift;
        $self->plugin_handlers(
			'multi_bash.org'=>'get_bash'
			);
}

sub get_bash {
 my ($self,$message)=@_;
 use LWP::Simple;
	my $num;
	if ($message->command_input() =~ /^\d+$/ ) { $num = $message->command_input(); } else { 
	my @num;
	my $rand_quotes= get"http://bash.org/?random";
	while ($rand_quotes =~ /<p class="quote"><a href="\?(\d+)" title="Permanent link to this quote.">/g) { push(@num, $1); } $num = $num[rand($#num)]; }
	my $text = get"http://bash.org/?$num";
	if ( $text =~ /Quote #\d+ does not exist./ ) { $self->respond($message,"Quote $num does not exist :-("); return; }
		if ($text =~ /<p class="quote"><a href="\?$num" title="Permanent link to this quote."><b>#$num<\/b>.*?<\/a><\/p><p class="qt">(.*?)<\/p>\s*<\/td>/s) 
			{ 	$text = $1;
				$text =~ s/&quot;/"/g; $text =~ s/&apos;/'/g; $text =~ s/&amp;/&/g; $text =~ s/\n+/\n/g;
				$text =~ s/&nbsp;/ /g; $text =~ s/<[^>]+>//g; $text =~ s/&lt;/</g; $text =~ s/&gt;/>/g;
			}
	my @text = split("\n",$text);
	$self->respond($message,"========== $num ==========");
	foreach (@text) 
	{
		$self->respond($message,$_);
	}
	$self->respond($message,"========== End ==========");
}

 1;
 