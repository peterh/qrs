package Qrs::Plugin::note;
use Moose;

use 5.10.0;

use strict;
use warnings;

use Storable qw/nstore retrieve/;

has 'qrs' => ( is => 'ro', isa => 'Qrs', required => 1 );

has 'name' => ( is => 'ro', isa => 'Str', default => 'note', init_arg => undef );
has 'doc' => ( is => 'ro', isa => 'Str', init_arg => undef, default => 
             "note | List notes\nnote <note> | Display note <note>\n".
             "note <note> <description> | Set note <note> to <description>\n".
             "note <note> - | Delete note <note>" );


sub do {
   my $self = shift;
   my %arg = @_;

   my $buf;

   my $body = $arg{body};
   my @cmd;

   my $notes = {};
   my $store = $self->qrs->store_file($arg{message}->from(), 'note');
   $notes = retrieve($store) // {} if (-r $store);

   my $reply = $arg{message}->make_reply();

   if ($body =~ /^\s*$/) {
      $reply->add_body("Known notes: ". join(' ', sort keys %$notes));
      $reply->send();
      return;
   }

   if ($body =~ /^\s*(\S+)\s*$/) {
      $reply->add_body($notes->{$1} // "Unknown note: ". $1);
      $reply->send();
      return;
   }

   $body =~ s/^\s*(\S+)\s*//;
   my $note = $1;
   if ($body eq '-') {
      delete $notes->{$note};
      $reply->add_body("Note '$note' deleted.");
   } else {
      $notes->{$note} = $body;
      $reply->add_body("Note '$note' stored.");
   }

   nstore $notes, $store;

   $reply->send();
}

1;
