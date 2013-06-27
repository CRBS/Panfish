package Mock::NoSortPathSorter;


use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
  Mock::NoSortPathSorter -- Perform no sorting

=head1 DESCRIPTION

Dummy object that does no sorting, it just returns the array given to 
it.

=head1 METHODS

=head3 new

Creates new instance of Job object

my $sorter = Mock::NoSortPathSorter->new();

=cut

sub new {
   my $class = shift;
   my $self = {};

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 sort

Does nothing just returns array passed to it

my @sortedPaths = $sorter->sort(\@paths);

=cut

sub sort {
   my $self = shift;
   my $inputPaths = shift;
   my @emptyArr;
   if (!defined($inputPaths)){
       return @emptyArr;
   }
   
   # sometimes we get a string and no array so lets just return it in an array
   if (ref($inputPaths) ne 'ARRAY'){
       my @tmpArr;
       push(@tmpArr,$inputPaths);
       return @tmpArr;
   }

   return @{$inputPaths};
   
}

1;

__END__


=head1 AUTHOR

Mock::NoSortPathSorter is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

