package Panfish::RemoteIO;

use strict;
use English;
use warnings;

use File::Basename;

use FindBin qw($Bin);

use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::Executor;

=head1 SYNOPSIS
   
  Panfish::RemoteIO -- Transfers data to/from remote hosts via rsync

=head1 DESCRIPTION

Contains set of methods that allows transfer of data to and from
remote hosts via rsync

=head1 METHODS

=head3 new

=cut

sub new {
   my $class = shift;
   my $self = {
     Config          => shift,
     SSHExecutor     => shift,
     Logger          => shift,
     ConnectTimeOut  => 360,
     RetryCount      => 10,
     RetrySleep      => 10,
     TimeOut         => 180
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}


=head3 directUpload

Uploads path passed in to path specified

=cut

sub directUpload {
    my $self = shift;
    my $pathToUpload = shift;
    my $destinationDir = shift;
    my $cluster = shift;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Uploading $pathToUpload to $cluster:$destinationDir/.");
    }

    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    my $parentDir = dirname($destinationDir); 

    

    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->enableSSH();

    my $checkExit = $self->{SSHExecutor}->executeCommand("/bin/mkdir -p $parentDir",30);
    if ($checkExit != 0){
        return "Unable to create $parentDir on $cluster";
    }

    $self->{SSHExecutor}->disableSSH();
    my $tryCount = 1;
    my $cmd = "/usr/bin/rsync -rtpz --stats --timeout=180 -e ssh $pathToUpload ".$self->{Config}->getHost($cluster).":$destinationDir";
    $self->{Logger}->debug("Running $cmd");
    while ($tryCount <= $self->{RetryCount}){

        if ($tryCount > 1){
            $self->{Logger}->debug("Sleeping ".$self->{RetrySleep});
            sleep $self->{RetrySleep};
        }

        # okay lets try the upload now 
        $checkExit = $self->{SSHExecutor}->executeCommand($cmd);


        if ($checkExit == 0){
            return undef;
        }
        $self->{Logger}->error("Try # $tryCount received error when attempting upload : ".
                               $self->{SSHExecutor}->getOutput());

        $tryCount++;
    }

    return "Unable to upload after ".$self->{RetryCount}. " tries.  Giving up";



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


    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    my $parentDir = dirname($dirToUpload); 

    my $remoteParentDir = $self->{Config}->getBaseDir($cluster).$parentDir;

    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->enableSSH();

    my $checkExit = $self->{SSHExecutor}->executeCommand("/bin/mkdir -p $remoteParentDir",30);
    if ($checkExit != 0){
        return "Unable to create $remoteParentDir on $cluster";
    }

    $self->{SSHExecutor}->disableSSH();
    my $tryCount = 1;
    my $cmd = "/usr/bin/rsync -rtpz --stats --timeout=180 -e ssh $dirToUpload ".$self->{Config}->getHost($cluster).":$remoteParentDir";
    $self->{Logger}->debug("Running $cmd");
    while ($tryCount <= $self->{RetryCount}){
       
        if ($tryCount > 1){
            $self->{Logger}->debug("Sleeping ".$self->{RetrySleep});
            sleep $self->{RetrySleep};
        }
        
        # okay lets try the upload now 
        $checkExit = $self->{SSHExecutor}->executeCommand($cmd);

  
        if ($checkExit == 0){
            return undef;
        }
        $self->{Logger}->error("Try # $tryCount received error when attempting upload : ".
                               $self->{SSHExecutor}->getOutput());
        
        $tryCount++;
    }

    return "Unable to upload after ".$self->{RetryCount}. " tries.  Giving up";
}


sub download {
    my $self = shift;
    my $dirToDownload = shift;
    my $cluster = shift;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Directory to download: $dirToDownload from $cluster");
    }


    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    my $parentDir = dirname($dirToDownload);

    my $remoteDir = $self->{Config}->getBaseDir($cluster).$dirToDownload;

    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->disableSSH();
    my $tryCount = 1;
    my $cmd = "/usr/bin/rsync -rtpz --stats --timeout=180 -e ssh ".
              $self->{Config}->getHost($cluster).":$remoteDir ".$parentDir."/.";
    $self->{Logger}->debug("Running $cmd");
    while ($tryCount <= $self->{RetryCount}){

        if ($tryCount > 1){
            $self->{Logger}->debug("Sleeping ".$self->{RetrySleep});
            sleep $self->{RetrySleep};
        }

        # okay lets try the upload now 
        my $checkExit = $self->{SSHExecutor}->executeCommand($cmd);


        if ($checkExit == 0){
            return undef;
        }
        $self->{Logger}->error("Try # $tryCount received error when attempting download : ".
                               $self->{Config}->getHost($cluster).":$remoteDir ");
       $tryCount++;
    }

    return "Unable to download after ".$self->{RetryCount}. " tries.  Giving up";
}

1;

__END__

=head1 AUTHOR

Panfish::RemoteIO is written by Christopher Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut

