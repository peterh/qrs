package Qrs::Plugin::calc;
use Moose;

use 5.10.1; # IPC::Cmd is unsafe in 5.10 and before

use strict;
use warnings;

use IPC::Cmd qw/can_run run/;

has 'qrs' => ( is => 'ro', isa => 'Qrs', required => 1 );

has 'name' => ( is => 'ro', isa => 'Str', default => 'calc', init_arg => undef );
has 'doc' => ( is => 'ro', isa => 'Str', init_arg => undef, default => 
             "calc <expression> | Calculate <expression>\ncalc <have> ! <want> | Convert <have> to <want>\n".
             "\nCalc is based on 'units'. See http://www.gnu.org/software/units/#examples for more information." );

my $units = can_run('units') or die ("Cannot find units\n");

sub do {
   my $self = shift;
   my %arg = @_;

   my $buf;

   my $body = $arg{body};
   my @cmd;

   if ($body =~ /^(.+)!(.+)$/) {
      push @cmd, $1, $2;
   } else {
      push @cmd, $body;
   }

   run(command => [$units, '--one-line', '--quiet', '--compact', @cmd ],
       verbose => 0,
       buffer  => \$buf,
       timeout => 60 );

   chomp $buf;

   my $reply = $arg{message}->make_reply();
   $reply->add_body($buf);
   $reply->send();
}

1;
