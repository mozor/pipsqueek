package PipSqueek::Plugin::Mathbin;
use strict;
use warnings;
use base qw(PipSqueek::Plugin);

use LWP::UserAgent;
use URI::Escape qw(uri_escape);

our $MATHBIN_BACKEND = 'http://www.mathbin.net/backend.html';

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers({
		'multi_mathbin' => 'mathbin',
	});
}


sub mathbin
{
	my ($self, $message) = @_;
	my $user = $self->search_or_create_user($message)->{username};

	my $eq = $message->command_input();
	$eq =~ s/^\s+//;
	$eq =~ s/\s+$//;

	if ($eq) {
		my $ua = LWP::UserAgent->new();
		my $url = $MATHBIN_BACKEND . '?eq=' . uri_escape($eq)
			. '&name=' . uri_escape($user);
		my $res = $ua->get($url);

		unless ($res->is_success() && $res->content_type() eq 'text/html') {
			return $self->respond($message, "HTTP Error or invalid content type");
		}

		my $rv = $res->content();
		my ($code, $msg) = map { s/^\s+//; s/\s+$//; $_ } split /\n/, $rv;
		$code ||= '0';
		$msg ||= 'Very mysterious error';
		if ($code eq '0') {
			$self->respond($message, "Error: $msg");
		} else {
			$self->respond($message, $msg);
		}
	} else {
		$self->respond($message, "You must provide an equation." );
	}
}

1;
