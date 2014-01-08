package Mock::JobHashFactory;

use strict;
use English;
use warnings;


=head1 SYNOPSIS
   
Mock::JobHashFactory -- Mock Factory to create JobHashes

=head1 DESCRIPTION

Mocks JobHashFactory

=head1 METHODS

=head3 new

Creates new instance of JobHashFactory object

=cut

sub new {
   my $class = shift;
   my $self = {
     JobHash => undef,
     JobHashError => undef
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

sub addGetJobHashResult {
   my $self = shift;
   my $jobs = shift;
   my $resultHash = shift;
   my $resultError = shift;

   push(@{$self->{JobHash}},$resultHash);
   push(@{$self->{JobHashError}},$resultError);
}

sub getJobHash {
   my $self = shift;
   my $jobs = shift;

   return (pop(@{$self->{JobHash}}),pop(@{$self->{JobHashError}}));
}

1;

__END__


=head1 AUTHOR

Mock::JobHashFactory is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


