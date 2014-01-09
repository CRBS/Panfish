package Mock::PsubFileFromJobsCreator;

use strict;
use English;
use warnings;


=head1 SYNOPSIS
   
Mock::PsubFileFromJobsCreator -- Mock Object to create psub file

=head1 DESCRIPTION

Mocks JobHashFactory

=head1 METHODS

=head3 new

Creates new instance of PsubFileFromJobsCreator object

=cut

sub new {
   my $class = shift;
   my $self = {
     Create => undef,
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

sub addCreateResult {
   my $self = shift;
   my $cluster = shift;
   my $jobsArrayRef = shift;
   my $result = shift;

   push(@{$self->{Create}->{$cluster}},$result);
}

sub create {
   my $self = shift;
   my $cluster = shift;
   my $jobsArrayRef = shift;

   return pop(@{$self->{Create}->{$cluster}});
}

1;

__END__


=head1 AUTHOR

Mock::PsubFileFromJobsCreator is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


