package Qrs::Plugin::remind;
use Moose;

use 5.10.0;

use strict;
use warnings;

use Storable qw/nstore retrieve/;

has 'qrs' => ( is => 'ro', isa => 'Qrs', required => 1 );

has 'name' => ( is => 'ro', isa => 'Str', default => 'remind', init_arg => undef );

has 'seen' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

sub BUILD {
   my $self = shift;
   $self->qrs->xmpp->reg_cb(
      presence_update => sub {
         my ($cl, $acc, $r, $contact, $old, $new) = @_;

         if (!defined($new)) {
            # Going offline
            delete $self->seen->{$contact->jid};
            return;
         }
         
         return if ($self->seen->{$contact->jid});  # Already 'seen' (online)

         $self->seen->{$contact->jid} = 1;

         # Send all reminders
         my $notes = [];
         my $store = $self->qrs->store_file($new->jid(), 'remind');
         $notes = retrieve($store) // [] if (-r $store);

         for my $i (1..@$notes) {
            $contact->make_message(
                  body => "Reminder $i - ".$notes->[$i-1],
               )->send();
         }
      },
   );
}

sub do {
   my $self = shift;
   my %arg = @_;

   my $buf;

   my $body = $arg{body};
   my @cmd;

   my $notes = [];
   my $store = $self->qrs->store_file($arg{message}->from(), 'remind');
   $notes = retrieve($store) // [] if (-r $store);

   my $reply = $arg{message}->make_reply();

   if ($body =~ /^\s*$/) {
      my $msg = "Active Reminders:";
      for my $i (1..@$notes) {
         $msg .= "\n$i - ".$notes->[$i-1];
      }
      $reply->add_body($msg);
      $reply->send();
      return;
   }

   if ($body =~ /^\s*-$/) {
      $notes = [];
      $reply->add_body("All reminders deleted");
   } elsif ($body =~ /^\s*-\s+(\d+)\s*$/) {
      my $del = $1;
      if ($del > scalar @$notes) {
         $reply->add_body("Unknown reminder $del");
         $reply->send();
         return;
      }
      splice @$notes, $del-1, 1;
      $reply->add_body("Reminder $del deleted");
   } else {
      push @$notes, $body;
      $reply->add_body("Reminder added");
   }

   nstore $notes, $store;

   $reply->send();
}

1;
