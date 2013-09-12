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
     FileUtil        => shift,
     RsyncBin        => "/usr/bin/rsync",
     SshBin          => "/usr/bin/ssh",
     MkdirBin        => "/bin/mkdir",
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
    my $excludeRef = shift;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Uploading $pathToUpload to $cluster:$destinationDir/.");
    }

    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    my $parentDir = $self->{FileUtil}->getDirname($destinationDir); 

    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->enableSSH();

    my $checkExit = $self->{SSHExecutor}->executeCommandWithRetry($self->{Config}->getIORetryCount($cluster),
                                                                  $self->{Config}->getIORetrySleep($cluster),
                                                                  $self->{MkdirBin}." -p $parentDir",
                                                                  $self->{Config}->getIOTimeout($cluster));
    if ($checkExit != 0){
        return "Unable to create $parentDir on $cluster";
    }

    my $excludeArgs = $self->_createExcludeArgs($excludeRef);

    $self->{SSHExecutor}->disableSSH();
    my $cmd = $self->{RsyncBin}." -rtpz $excludeArgs --stats --timeout=".
                                $self->{Config}->getIOTimeout($cluster).
                                " -e \"".$self->{SshBin}."\" $pathToUpload ".
                                $self->{Config}->getHost($cluster).":$destinationDir 2>&1";
    $self->{Logger}->debug("Running $cmd");

    # okay lets try the upload now 
    $checkExit = $self->{SSHExecutor}->executeCommandWithRetry($self->{Config}->getIORetryCount($cluster),
                                                               $self->{Config}->getIORetrySleep($cluster),$cmd);
    if ($checkExit == 0){
        return undef;
    }

    return "Unable to upload after ".
           $self->{Config}->getIORetryCount($cluster).
           " tries.  Giving up";
}

=head3 delete

Deletes path on remote cluster

=cut

sub delete {
    my $self = shift;
    my $dirToDelete = shift;
    my $cluster = shift;
   
    my $remoteDir = $self->{Config}->getBaseDir($cluster).$dirToDelete;

    # invoke removedir on path
    $self->{Logger}->debug("Attempting to delete $remoteDir on cluster $cluster");

    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->enableSSH();

    my $cmd = $self->{Config}->getPanfishSetup($cluster)." --removedir $remoteDir";


    my $checkExit = $self->{SSHExecutor}->executeCommandWithRetry($self->{Config}->getIORetryCount($cluster),
                                                                  $self->{Config}->getIORetrySleep($cluster),
                                                                  $cmd);
    if ($checkExit != 0){
        return "Unable to run ".$self->{SSHExecutor}->getCommand().
                               "  : ".$self->{SSHExecutor}->getOutput();
    }
    return undef;
}

=head3 deleteAndUpload 

Uploads path passed in to remote cluster, but first deletes
that path on the remote cluster
 
=cut

sub deleteAndUpload {
    my $self = shift;
    my $dirToUpload = shift;
    my $cluster = shift;
    my $excludeRef = shift;

    my $res = $self->delete($dirToUpload,$cluster);
    if (defined($res)){
        return $res;
    }
    
    return $self->upload($dirToUpload,$cluster,$excludeRef);
}

=head3 upload

Uploads path passed in to remote cluster.

my $status = $uppy->upload("/home/foo/data1","gordon_shadow.q",\@excludeRef);

Method returns undef upon success or string with error message
upon failure.

=cut

sub upload {
    my $self = shift;
    my $dirToUpload = shift;
    my $cluster = shift;
    my $excludeRef = shift;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Directory to upload: $dirToUpload to $cluster");
    }


    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    my $parentDir = $self->{FileUtil}->getDirname($dirToUpload); 

    my $remoteParentDir = $self->{Config}->getBaseDir($cluster).$parentDir;

    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->enableSSH();

    my $mkdirCmd = $self->{MkdirBin}." -p $remoteParentDir";

    $self->{Logger}->debug($mkdirCmd);

    my $checkExit = $self->{SSHExecutor}->executeCommandWithRetry($self->{Config}->getIORetryCount($cluster),
                                                                  $self->{Config}->getIORetrySleep($cluster),
                                                                  $mkdirCmd, 
                                                                  $self->{Config}->getIOTimeout($cluster));
    if ($checkExit != 0){
        return "Unable to create $remoteParentDir on $cluster";
    }

    $self->{SSHExecutor}->disableSSH();

    my $excludeArgs = $self->_createExcludeArgs($excludeRef);

    my $tryCount = 1;
    my $cmd = $self->{RsyncBin}." -rtpz $excludeArgs --stats --timeout=".
                                $self->{Config}->getIOTimeout($cluster).
                                " -e \"".$self->{SshBin}."\" $dirToUpload ".
                                $self->{Config}->getHost($cluster).
                                ":$remoteParentDir 2>&1";

    $self->{Logger}->debug("Running $cmd");
        
    # okay lets try the upload now 
    $checkExit = $self->{SSHExecutor}->executeCommandWithRetry($self->{Config}->getIORetryCount($cluster),
                                                               $self->{Config}->getIORetrySleep($cluster),
                                                               $cmd);
  
    if ($checkExit == 0){
       return undef;
    }

    return "Unable to upload after ".
           $self->{Config}->getIORetryCount($cluster).
           " tries.  Giving up";
}

=head3 download

Downloads path from cluster specified. The path will be prefixed with the
basedir path for that cluster.  

my $check = $rmIO->download("/some/path","cluster",\@excludePatterns);

=cut

sub download {
    my $self = shift;
    my $dirToDownload = shift;
    my $cluster = shift;
    my $excludeRef = shift;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Directory to download: $dirToDownload from $cluster");
    }

    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    my $parentDir = $self->{FileUtil}->getDirname($dirToDownload);

    my $remoteDir = $self->{Config}->getBaseDir($cluster).$dirToDownload;

    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->disableSSH();

    my $excludeArgs = $self->_createExcludeArgs($excludeRef);

    my $tryCount = 1;
    my $cmd = $self->{RsyncBin}." -rtpz $excludeArgs --stats --timeout=".
              $self->{Config}->getIOTimeout($cluster).
              " -e \"".$self->{SshBin}."\" ".
              $self->{Config}->getHost($cluster).":$remoteDir ".$parentDir."/. 2>&1";
    $self->{Logger}->debug("Running $cmd");

    # okay lets try the upload now 
    my $checkExit = $self->{SSHExecutor}->executeCommandWithRetry($self->{Config}->getIORetryCount($cluster),
                                                                  $self->{Config}->getIORetrySleep($cluster),
                                                                  $cmd);
        
    if ($checkExit == 0){
       return undef;
    }

    return "Unable to download after ".
           $self->{Config}->getIORetryCount($cluster).
           " tries.  Giving up";
}


#
##
##
#
#
#
sub _createExcludeArgs {
    my $self = shift;
    my $excludeRef = shift;
    my $excludeArgs = "";
    if (defined($excludeRef)){
         for (my $x = 0; $x < @$excludeRef; $x++){
             if (defined(@{$excludeRef}[$x])){
                 @{$excludeRef}[$x]=~s/'/\\'/g;
                 $excludeArgs .= "--exclude '".@{$excludeRef}[$x]."' ";
             }
         }
    }
    return $excludeArgs;
}

=head3 getDirectorySize

This method takes a directory path and determines
disk space consumed by files in this path on the cluster
specified.  This method will IGNORE any symbolic links.  
The method returns a lot of data in separate variables.  
The last variable $error if set means there was a problem.
A value of undef in $error means we are good.

Note: The command will prefix the base directory onto path specified.

my ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error) = $f->getDirectorySize("/foo","cluster");

=cut

sub getDirectorySize {
    my $self = shift;
    my $path = shift;
    my $cluster = shift;

    if (!defined($path)){
       return (0,0,0,0,"Path is not defined");
    }

    if (!defined($cluster)){
       return (0,0,0,0,"Cluster is not defined");
    }

    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    my $remoteDir = $self->{Config}->getBaseDir($cluster).$path;
    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->enableSSH();

    # call panfishsetup with --examinedir flag on remote cluster
    # this command will tell us disk consumed and output in this format
    # num.files=6
    # num.dirs=1
    # num.symlinks=0
    # size.in.bytes=25757
    # error=
    my $numFiles = 0;
    my $numDirs = 0;
    my $numSymlinks = 0;
    my $sizeInBytes = 0;
    my $error = undef;

    my $panfishSetup = $self->{Config}->getPanfishSetup($cluster)." --examinedir $remoteDir";
    $self->{Logger}->debug("Running $panfishSetup");

    my $exit = $self->{SSHExecutor}->executeCommandWithRetry($self->{Config}->getIORetryCount($cluster),
                                                             $self->{Config}->getIORetrySleep($cluster),
                                                             $panfishSetup,undef,undef);
 
    # if we get a non zero exit code bail
    if ($exit != 0){
       $self->{Logger}->error("Unable to run ".$self->{SSHExecutor}->getCommand().
                               "  : ".$self->{SSHExecutor}->getOutput());
       return (0,0,0,0,$self->{SSHExecutor}->getOutput());
    }

    $self->{Logger}->debug("Output : ".$self->{SSHExecutor}->getOutput());
    my @rows = split("\n",$self->{SSHExecutor}->getOutput());
    for (my $x = 0; $x < @rows; $x++){
       chomp($rows[$x]); 
       if ($rows[$x]=~/^(.*)=(.*)$/){
           
           my $key = $1;
           my $val = $2;
           if ($key eq "num.files"){
              $numFiles = $val;
           }
           elsif ($key eq "num.dirs"){
              $numDirs = $val;
           }
           elsif ($key eq "num.symlinks"){
              $numSymlinks = $val;
           }
           elsif ($key eq "size.in.bytes"){
              $sizeInBytes = $val;
           }
           elsif ($key eq "error"){
              if ($val ne "" &&
                  chop($val) ne " "){
                 $error = $val;
              }
           }
      }
    }
    $self->{Logger}->debug("numFiles=$numFiles, numDirs=$numDirs, numSymlinks=$numSymlinks, sizeInBytes=$sizeInBytes");
    return ($numFiles,$numDirs,$numSymlinks,$sizeInBytes,$error);
}

=head3 exists

Checks if path exists on remote system returning  1 if it exists in the
$val variable and 0 if not.  If there was an error it will be set in
$error

my ($val,$error) = $remoteIo->exists("/foo/somefile","foo.cluster");

=cut

sub exists {
    my $self = shift;
    my $path = shift;
    my $cluster = shift;

    if (!defined($path)){
       return (0,"Path is not defined");
    }

    if (!defined($cluster)){
       return (0,"Cluster is not defined");
    }

    # unset any command which is piped to the command to execute
    $self->{SSHExecutor}->setStandardInputCommand(undef);

    my $remoteDir = $self->{Config}->getBaseDir($cluster).$path;
    $self->{SSHExecutor}->setCluster($cluster);

    $self->{SSHExecutor}->enableSSH();

    my $panfishSetup = $self->{Config}->getPanfishSetup($cluster)." --exists $remoteDir";
    $self->{Logger}->debug("Running $panfishSetup");

    my $exit = $self->{SSHExecutor}->executeCommandWithRetry($self->{Config}->getIORetryCount($cluster),
                                                             $self->{Config}->getIORetrySleep($cluster),
                                                             $panfishSetup,undef,undef);
    # if we get a non zero exit code bail
    if ($exit != 0){
       $self->{Logger}->error("Unable to run ".$self->{SSHExecutor}->getCommand().
                               "  : ".$self->{SSHExecutor}->getOutput());
       return (0,$self->{SSHExecutor}->getOutput());
    }

    $self->{Logger}->debug("Output : ".$self->{SSHExecutor}->getOutput());
    my @rows = split("\n",$self->{SSHExecutor}->getOutput());
    my $exists = 0;
    my $key;
    my $val;
    my $error = undef;
    for (my $x = 0; $x < @rows; $x++){
       chomp($rows[$x]);
       if ($rows[$x]=~/^(.*)=(.*)$/){
           $key = $1;
           $val = $2;
           if ($key eq "exists"){
              if ($val eq "yes"){
                 $exists = 1;
              }
              last;
           }
       }
    }
    if ($key ne "exists"){
      $error = "exists key not found in output";
    }
    return ($exists,$error);
}


1;

__END__

=head1 AUTHOR

Panfish::RemoteIO is written by Christopher Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut

