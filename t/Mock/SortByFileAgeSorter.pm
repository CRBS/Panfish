package Mock::SortByFileAgeSorter;

use strict;
use English;
use warnings;


=head1 SYNOPSIS
   
Mock::SortByFileAgeSorter -- Mock Object to sort files by age

=head1 DESCRIPTION

Mocks SortByFileAgeSorter

=head1 METHODS

=head3 new

Creates new instance of SortByFileAgeSorter object

=cut

sub new {
   my $class = shift;
   my $self = {
     Sort => undef,
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

sub addSortResult {
   my $self = shift;
   my $inputPaths = shift;
   my $resultArrayRef = shift;

   push(@{$self->{Sort}},$resultArrayRef);
}

sub sort {
   my $self = shift;
   my $inputPaths = shift;

   my $resultRef = pop(@{$self->{Sort}});

   if (!defined($resultRef)){
     return undef;
   }

   return @{$resultRef};
}

1;

__END__


=head1 AUTHOR

Mock::SortByFileAgeSorter is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


