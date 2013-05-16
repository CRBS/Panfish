package Panfish::FileLock;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::Logger;
use Panfish::FileReaderWriterImpl;
use Panfish::Executor;

=head1 SYNOPSIS
   
  Panfish::LockFileFactory -- Creates a lock file

=head1 DESCRIPTION

Creates lock files

=head1 METHODS

=head3 new

Creates new instance of LockFileFactory



=cut

sub new {
   my $class = shift;
   my $self = {
     Logger         => shift,
     FileUtil       => shift,
     Executor       => shift,
     ReaderWriter   => shift
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 create

This method creates a lock using the path to the file given
by first checking for that files existance and reading the pid
within that file.  If the pid matches the current process pid passed
in then the lock fails.  If the pid differs, the code creates the
file and writes a new pid in its place.  The return value is undef upon
success otherwise the error will be returned as a string.

my $error = $flock->create($lockFile,$pid);

=cut

sub create {
    my $self = shift;
    my $lockFile = shift;
    my $pid = shift;

    if (!defined($lockFile)){
        $self->{Logger}->error("Lockfile is not set");
        return "Lockfile is not set";
    }

    if (!defined($pid)){
       $self->{Logger}->error("Pid is not set");
       return "Pid is not set";
    }

    # check for existance of file and if found get the pid from it
    my ($pidFromLockFile,$error) = $self->_getPidFromLockFile($lockFile); 

    # if we got an error, just bail    
    if (defined($error)){
       $self->{Logger}->error($error);
       return $error;
    }

    # if we got a pid file just return saying we can't make a lock
    if (defined($pidFromLockFile)){
       chomp($pidFromLockFile);
       $self->{Logger}->debug("Lock file $lockFile with pid $pidFromLockFile found.  Unable to create lock");
       return "Lock file $lockFile with pid $pidFromLockFile found.  Unable to create lock";
    }
    
    # Create lock file and write pid to it
    my $res = $self->{ReaderWriter}->openFile(">".$lockFile);
    if (defined($res)){
       $self->{Logger}->error("Unable to open $lockFile for writing : $res");
       return "Unable to open $lockFile for writing : $res";
    }

    $self->{ReaderWriter}->write($pid."\n");
    $self->{ReaderWriter}->close();

    return undef;
}


#
# Looks at lock file and if it exists, the code
# extracts the pid and returns it otherwise undef
# is returned
#
sub _getPidFromLockFile {
   my $self = shift;
   my $lockFile = shift;

   my $res = $self->{FileUtil}->runFileTest("-f",$lockFile);
   if (!defined($res)){
      return (undef,undef);
   }

   $res = $self->{ReaderWriter}->openFile($lockFile);
   if (defined($res)){
      return (undef,"Unable to open $lockFile to get pid : $res");
   }
   my $pid = $self->{ReaderWriter}->read();
   $self->{ReaderWriter}->close();

   return ($pid,undef);
}


1;

__END__

=head1 AUTHOR

Panfish::FileLock is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

