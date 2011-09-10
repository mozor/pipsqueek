#
# The format it takes is quite flexible.
# bot: (decide|pick|choose) this, that or the other
# bot: (decide|pick|choose) (among|between|from|one of) a and b or c
# bot: should i this or that?
# bot: should foo this or that?
# !decide ...
# !pick ...
# And so on
#
package PipSqueek::Plugin::Decide;
use base qw(PipSqueek::Plugin);

our $SPAM_TIMEOUT = 20; # Seconds

sub plugin_initialize
{
    my $self = shift;

    $self->plugin_handlers([
        'irc_public',
        'multi_decide',
        'multi_pick',
        'multi_choose',
    ]);

    # { who => $who, text => "@choices", ts => time() }
    $self->{_prevent_spam} = {};
}

sub decide
{
    my ($self, $text, $who) = @_;
   
    $text =~ s/\bmy\b/your/g;

    my @choices =
        grep { length }
        map { s/^\s+//; s/\s+$//; s/\s*[\?!\.]+$//; $_ }
        split(/(?:\Wor\W|,|\|\|)/i, $text);

    my $spam = $self->{_prevent_spam};
    for (keys %{$spam}) {
        if (time() - $spam->{$_}->{ts} > $SPAM_TIMEOUT) {
            delete $spam->{$_};
        }
    }
    for (keys %{$spam}) {
        if ($spam->{$_}->{text} eq "@choices"
            && (! exists $spam->{$_}->{who} || $spam->{$_}->{who} eq $who))
        {
            $spam->{$_}->{ts} = time();
            return "I JUST told you!";
        }
    }
    my $new_key = "@choices" . defined $who ? $who : '';
    $spam->{$new_key} = { text => "@choices", ts => time() };
    $spam->{$new_key}->{who} = $who if defined $who;

    # More than one choice
    if (scalar @choices > 1) {
        # srand time;
        my $rv = @choices[rand @choices] . '.';
        if (defined $who) {
            $rv = "$who should $rv";
        }
        # Randomly say "neither" for 2 choices
        if (scalar @choices == 2 && !(int(rand 66))
            && lc($choices[1]) ne 'not')
        {
            $rv = "Neither.";
        }
        return $rv;
    # One choice
    } elsif (scalar @choices) {
        my @opts = ('Yes.', 'No.');
        # srand time;
        return @opts[rand @opts];
    # No choices
    } else {
        return "I don't know.";
    }
}

# Currently this could be done with multi_shall, multi_should ...
# but I wanted to keep it more flexible.  If I don't end up needing 
# irc_public, this can be switched relatively simply.
sub irc_public
{
    my ($self,$message) = @_;

    my $text = $message->message();

    my $botnick = $self->config()->current_nickname();
    if ($text =~ /^$botnick[\s,:;]+(?:should|shall)\s+(\S+)\s+(.+)$/i) {
        my $who = $1;
        my $decision;
        # "should I.." or "should my_nick ..."
        if (lc($who) eq 'i' || lc($who) eq lc($message->nick())) {
            $decision = $self->decide($2, "You");
            $decision =~ s/\bmy\b/your/i;
        # "should the bot..."
        } elsif (lc($who) eq lc($botnick) || lc($who) eq 'you') {
            my @opts = ("HAH! I'll do whatever I want.",
                "That's my choice, and none of your business.");
            # srand time;
            $decision = @opts[rand @opts];
        } else {
            $decision = $self->decide($2, $who);
        }
        $self->respond($message, $decision);
    }
}

sub multi_decide { return multi_decider(@_) }
sub multi_choose { return multi_decider(@_) }
sub multi_pick   { return multi_decider(@_) }

sub multi_decider
{
    my ($self,$message) = @_;
    my $text = $message->command_input();
    my $who = $self->search_user( $message )->{ 'username' };

    if ($text =~ /^(?:among|between|one of|from)\s+/i) {
        $text =~ s/^(?:among|between|one of|from)\s+//i;
        $text =~ s/(?<=\W)and(?=\W)/or/gi;
    }
    my $decision = $self->decide($text);
    $self->respond($message, $decision);
}


1;


__END__
