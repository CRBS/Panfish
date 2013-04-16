package Mock::RemoteIO;

use strict;
use English;
use warnings;


sub new {
   my $class = shift;
   my $self = {
     Upload => undef
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}


=head3 addUploadResult

Sets expected value for upload
is set multiple times the values are pushed onto a queue

my $db->addUploadResult($dirToUpload,$cluster,\@excludeRef,$result);

=cut

sub addUploadResult {
   my $self = shift;
   my $dirToUpload = shift;
   my $cluster = shift;
   my $excludeRef = shift;
   my $result = shift;
   
   push(@{$self->{Upload}->{$dirToUpload.$cluster}},$result);

}


=head3 upload

Mock upload returns whatever was set in addUpload

=cut

sub upload {
   my $self = shift;
   my $dirToUpload = shift;
   my $cluster = shift;
   my $excludeRef = shift;
  
   return pop(@{$self->{Upload}->{$dirToUpload.$cluster}});
}



1;

__END__
