package Qrs;
use Module::Pluggable instantiate => 'new';
use Moose;

use 5.10.0;
use Time::Piece;
use File::Spec;

use AnyEvent;
use AnyEvent::XMPP::Client;

has 'signal' => ( is => 'ro', required => 1 );

has 'user' => ( is => 'ro', isa => 'Str', required => 1 );
has 'password' => ( is  => 'ro', isa  => 'Str', required => 1 );
has 'server' => ( is => 'ro', isa => 'Maybe[Str]' );

has 'store' => ( is => 'ro', isa => 'Str', required => 1 );

has 'client' => ( is => 'rw', isa => 'ArrayRef[Str]' );

has 'xmpp' => ( is => 'rw', init_arg => undef ); 
has 'pluglist' => ( is => 'rw', init_arg => undef ); 

sub BUILD {
    my $self = shift;

    $self->xmpp(new AnyEvent::XMPP::Client);
    $self->xmpp->add_account($self->user, $self->password, $self->server);

    my %dispatch;

    $self->xmpp->reg_cb(
        session_ready => sub {
            my ($cl, $acc) = @_;
            $cl->set_presence(undef, 'Send me "help" for info', 10);
        },
        message => sub {
            my ($cl, $acc, $message) = @_;
            
            my $body = $message->any_body();
            return unless (defined $body);  # filter out typing notifications

            $body =~ s/^\s*(\S+)\s*//;
            my $command = $1;

            return if (!defined($command)); # Ignore whitespace only

            $command = lc($command);
            if (defined($dispatch{$command})) {
                $dispatch{$command}->do(message => $message, body => $body);
            } else {
                my $reply = $message->make_reply();
                $reply->add_body("Unknown command: $command");
                $reply->send();
            }
        },
        contact_request_subscribe => sub {
            my ($cl, $acc, $r, $contact, $message) = @_;
            my %lookup = map { $_ => 1 } @{$self->client};
            if ($lookup{$contact->jid}) {
                $contact->send_subscribed();
                $contact->send_subscribe();
            } else {
                $contact->send_unsubscribed();
            }
        },
    );

    my @pluglist = $self->plugins(qrs => $self);
    $self->pluglist(\@pluglist);

    my %origname;
    foreach my $p (@pluglist) {
        my $name = lc($p->name);
        $dispatch{$name} = $p;
        $origname{$name} = 1;

        while (length($name) > 1) {
            $name = substr($name, 0, length($name)-1);
            if (defined $dispatch{$name}) {
                # Collision
                $p = 'bad value'; # Real commands cannot contain a space
            }
            $dispatch{$name} = $p if (!$origname{$name});
        }
        # Reset flagged values to undef
        foreach my $clear (keys %dispatch) {
            delete($dispatch{$clear}) if ($dispatch{$clear} eq 'bad value');
        }
    }
    $self->xmpp->start();
}

sub store_file {
    my ($self, $jid, $plugin) = @_;

    $jid =~ s[/.*$][];    # Filter out client identifier

    my $dir = File::Spec->catdir($self->store, $jid);
    -d $dir or mkdir($dir);

    return File::Spec->catfile($dir, $plugin);
}

1;
