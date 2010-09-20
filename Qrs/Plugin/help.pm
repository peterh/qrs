package Qrs::Plugin::help;
use Moose;

use 5.10.0;

use strict;
use warnings;

has 'qrs' => ( is => 'ro', isa => 'Qrs', required => 1 );

has 'name' => ( is => 'ro', isa => 'Str', default => 'help', init_arg => undef );

sub do {
   my $self = shift;
   my %arg = @_;

   my $buf = "Supported commands: ";

   my @cmds = map { $_->name; } @{$self->qrs->pluglist};
   $buf .= join (" ", sort @cmds);

   my $reply = $arg{message}->make_reply();
   $reply->add_body($buf);
   $reply->send();
}

1;
