package Qrs::Plugin::help;
use Moose;

use 5.10.0;

use strict;
use warnings;

has 'qrs' => ( is => 'ro', isa => 'Qrs', required => 1 );

has 'name' => ( is => 'ro', isa => 'Str', default => 'help', init_arg => undef );
has 'doc' => ( is => 'ro', isa => 'Str', init_arg => undef, default =>
             "help | List available commands\nhelp <command> | Display help for <command>" );

sub do {
   my $self = shift;
   my %arg = @_;

   my $reply = $arg{message}->make_reply();

   if ($arg{body} =~ /^\s*(\S+)\s*$/) {
      foreach my $cmd (@{$self->qrs->pluglist}) {
         if ($1 eq $cmd->name) {
            $reply->add_body($cmd->doc);
            $reply->send();
            return;
         }
      }
   }

   my $buf = "Supported commands: ";

   my @cmds = map { $_->name; } @{$self->qrs->pluglist};
   $buf .= join (" ", sort @cmds);
   $buf .= "\nhelp <command> for more details.";

   $reply->add_body($buf);
   $reply->send();
}

1;
