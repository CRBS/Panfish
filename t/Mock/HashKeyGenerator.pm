package Mock::HashKeyGenerator;

use strict;
use English;
use warnings;


sub new {
   my $class = shift;
   my $self = {
     HashKey => undef
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

sub addGetKeyResult {
   my $self = shift;
   my $job = shift;
   my $result = shift;
   push(@{$self->{HashKey}->{$job->getJobAndTaskId()}},$result);
}

sub getKey {
   my $self = shift;
   my $job = shift;
   return pop(@{$self->{HashKey}->{$job->getJobAndTaskId()}});
}

1;

__END__
