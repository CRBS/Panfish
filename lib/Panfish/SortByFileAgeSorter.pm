package Panfish::SortByFileAgeSorter;

use strict;
use English;
use warnings;
use Panfish::FileUtil;

=head1 SYNOPSIS
   
  Panfish::SortByFileAgeSorter -- Sorts array of file paths by modification time.

=head1 DESCRIPTION

Sorts array of file paths by modification time obtained with B<-M> Perl flag.  The
array is sorted so that files with oldest modification time are first.

=head1 METHODS

=head3 new

Creates new instance of Job object

my $sorter = Panfish::SortByFileAgeSorter->new($fUtil);

=cut

sub new {
   my $class = shift;
   my $self = {
     FileUtil  => shift
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 sort

Sorts array reference of file paths by last modification
time of file with files with oldest modifications at front
of list.

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

   if (@{$inputPaths} == 1){
      return @{$inputPaths};
   }

   return sort { $self->_sortByModificationTime } @{$inputPaths};
}

sub _sortByModificationTime {
   my $self = shift;
   my $a = $Panfish::SortByFileAgeSorter::a;
   my $b = $Panfish::SortByFileAgeSorter::b;

   my $aModTime = $self->{FileUtil}->runFileTest("-M",$a);
   my $bModTime = $self->{FileUtil}->runFileTest("-M",$b);
   
   if (!defined($aModTime) && !defined($bModTime)){
      return 0;
   }
   if (!defined($aModTime)){
      return 1;
   }
   if (!defined($bModTime)){
      return -1;
   }
   return $bModTime <=> $aModTime;
}

1;

__END__


=head1 AUTHOR

Panfish::SortByFileAgeSorter is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

