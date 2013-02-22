package Panfish::RsyncUploader;

use strict;
use English;
use warnings;

use File::Basename;

use FindBin qw($Bin);

use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::Executor;

=head1 SYNOPSIS
   
  Panfish::RsyncUploader -- Uploads directories to remote hosts via rsync

=head1 DESCRIPTION

 Uploads directories and their contents to remote hosts via rsync

=head1 METHODS

=head3 new

=cut

sub new {
   my $class = shift;
   my $self = {
     Config          => shift,
     Executor        => shift,
     SSHExecutor     => shift,
     Logger          => shift,
     ConnectTimeOut  => 360,
     RetryCount      => 10,
     RetrySleep      => 100,
     TimeOut         => 180
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 upload

Uploads path passed in to remote cluster passed in as well.

my $status = $uppy->upload("/home/foo/data1","gordon_shadow.q");

Method returns undef upon success or string with error message
upon failure.

=cut

sub upload {
    my $self = shift;
    my $dirToUpload = shift;
    my $cluster = shift;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Directory to upload: $dirToUpload to $cluster");
    }

    my $parentDir = dirname($dirToUpload); 

    my $remoteParentDir = $self->{Config}->getClusterBaseDir($cluster).$parentDir;

    $self->{SSHExecutor}->setCluster($cluster);

    my $checkExit = $self->{SSHExecutor}->executeCommand("/bin/mkdir -p $remoteParentDir",30);
    if ($checkExit != 0){
        return "Unable to create $remoteParentDir on $cluster";
    }

    # okay lets try the upload now
     
    $checkExit = $self->{Executor}->executeCommand("/usr/bin/rsync -rtpz --stats --timeout=180 -e ssh $dirToUpload ".$self->{Config}->getClusterHost($cluster).":$remoteParentDir");

    if ($checkExit != 0){
       return "Error uploading : ".$self->{Executor}->getOutput();
    }

    return undef;
}

1;

__END__

=head1 AUTHOR

Panfish::RsyncUploader is written by Christopher Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut

