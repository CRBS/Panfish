package Mock::JobKiller;

use strict;
use English;
use warnings;

sub new {
  my $class = shift;
   my $self = {
     KillJobResp => undef
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

sub addKillJobReturn {
   my $self = shift;
   my $response = shift;

   push(@{$self->{KillJobHash}},$response);
   
}

sub killJob {
  return pop(@{$self->{KillJobHash}});
}

1;

__END__
