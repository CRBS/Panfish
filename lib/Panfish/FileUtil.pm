package Panfish::FileUtil;

use strict;
use English;
use warnings;
use File::stat;
use File::Basename;
use File::Copy;
use File::Path;
use Panfish::Logger;

=head1 SYNOPSIS
   
  Panfish::FileUtil -- Set of File Utilities

=head1 DESCRIPTION

Set of File utility methods

=head1 METHODS

=head3 new

Creates new instance of Job object

my $fUtil = Panfish::FileUtil->new()

=cut

sub new {
   my $class = shift;
   my $self = {
     Logger          => shift
   };

   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 runFileTest

Wrapper for -X FILEHANDLE|EXPR|DIRHANDLE tests that
let caller test various paths.  

$fu->runFileTest("-f","/home/foo");

=cut

sub runFileTest {
   my $self = shift;
   my $flag = shift;
   my $path = shift;

   if ($flag eq "-e"){
      return -e $path;
   }
   if ($flag eq "-f"){
      return -f $path;
   }
   
   if ($flag eq "-M"){
      return -M $path;
   }

   if ($flag eq "-A"){
      return -A $path;
   }

   if ($flag eq "-C"){
      return -C $path;
   }

   die "unsupported flag : $flag";
}

=head3 removeLock

Deletes lock file 1 for success or 0 for failure.

=cut

sub removeLock {
    my $self = shift;
    my $lockFile = shift;
   
    if ( -f $lockFile ){
       return $self->deleteFile($lockFile);
    }
    return 1;
}


=head3 makePathUserGroupExecutable 

In effect makes whatever file passed in user rwx and group
rx and only readable for everyone else.
Ex:

-rwxr-xr--

$fUtil->makePathUserGroupExecutableAndReadable("/tmp/blah/foo.txt");

The return value is 1 upon success otherwise failure.

=cut

sub makePathUserGroupExecutableAndReadable {
    my $self = shift;
    my $path = shift;

    return chmod(0755,$path);
}



=head3 deleteFile

Deletes a file using unlink returning values from unlink
which should be 1 for success otherwise 0 for failure.

=cut

sub deleteFile {
    my $self = shift;
    return unlink(shift);
}

=head3 recursiveRemoteDir 

Removes a directory and any data within that directory

=cut

sub recursiveRemoveDir {
   my $self = shift;
   my $dir = shift;
   my $err;
   my $res = rmtree($dir);
   if (defined($err)){
       return 0;
   }
   return 1;
}

=head3 makeDir 

Creates directory specified.  THe parent directory must
already exist.

=cut

sub makeDir {
   my $self = shift;
   my $path = shift;
   return mkdir($path);
}


=head3 copyFile

Moves a file from a to b. Uses File::Copy copy method
returns 1 on success or 0 upon failure

=cut

sub copyFile {
    my $self = shift;
    my $a = shift;
    my $b = shift;
    return copy($a,$b);
}



=head3 moveFile 

Moves a file from a to b. Uses File::Copy move method
returns 1 on success or 0 upon failure

=cut

sub moveFile {
    my $self = shift;
    my $a = shift;
    my $b = shift;
    return move($a,$b);

}


=head3 getDirname 

Given a path to a file gets parent directory name
This implementation utilizes dirname() from File::Basename
module

=cut

sub getDirname {
    my $self = shift;
    my $file = shift;

    # return undef if undef is passed in
    if (!defined($file)){
       return undef;
    }

    return dirname($file);
}

=head3 getFilesInDirectory 

Given a directory this method returns all files in that
directory with full paths prefixed.  If any subdirectories
or symbolic links exist they are ignored.

my @files = $f->getFilesInDirectory("/tmp");

=cut
sub getFilesInDirectory {
    my $self = shift;
    my $dir = shift;
    if (!defined($dir)){
        $self->{Logger}->error("Directory path to search not set");
 	return undef;
    }

    if (!opendir(SUBDIR,$dir)){
        $self->{Logger}->error("Unable to open $dir : $!");
        return undef;
    }
    my @files;
    my $cnt = 0;
    my $dirEnt = readdir(SUBDIR);
    my $dirPath;
    while(defined($dirEnt)){
        $dirPath = $dir."/".$dirEnt;
        if (-f $dirPath){
            chomp($dirPath);
            $files[$cnt++] = $dirPath;
        }
        $dirEnt = readdir(SUBDIR);
    }
    closedir(SUBDIR);
    return @files;
}

=head3 getNumberFilesInDirectory

Gets number of files in a directory passed in. This method does NOT
examine any subdirectories.

=cut
sub getNumberFilesInDirectory {
    my $self = shift;
    my $dir = shift;
    if (!defined($dir)){
        $self->{Logger}->error("Directory path to search not set");
        return 0;
    }

    if (!opendir(SUBDIR,$dir)){
        $self->{Logger}->error("Unable to open $dir : $!");
        return 0;
    }
    my $cnt = 0;
    my $dirEnt = readdir(SUBDIR);
    my $dirPath;
    while(defined($dirEnt)){
        $dirPath = $dir."/".$dirEnt;
        if (-f $dirPath){
            $cnt++;
        }
        $dirEnt = readdir(SUBDIR);
    }
    closedir(SUBDIR);
    return $cnt;
}

=head3 getModificationTimeOfFile 

Gets last modify time of file in seconds since epoch

=cut

sub getModificationTimeOfFile {
    my $self = shift;
    my $file = shift;
    my $sb = stat($file);
    return $sb->mtime;
}


=head3 findFile

Given a directory path and a file name this
method returns the full path to the file if found
or undef if no file exists

my $fPath = $fUtil->findFile("/tmp","some.file");

=cut

sub findFile {
   my $self = shift;
   my $dir = shift;
   my $file = shift;
   my $excludeDirName = shift;
 
   if (!defined($excludeDirName)){
       $excludeDirName = "";
   } 

   if (!defined($dir)){
      $self->{Logger}->error("Dir is undefined");
     
      return undef;
   }
   if (!defined($file)){
      $self->{Logger}->error("File is undefined");
      return undef;
   }
 
   my $dh;

   if (!opendir($dh,$dir)){
      $self->{Logger}->error("Unable to open directory $dir : $!");
      return "Unable to open directory $dir : $!";
   }

   while (my $f = readdir($dh)){
      if ($f eq "." || 
          $f eq ".."){
        next;
      }

      if ($f eq $file){
        closedir($dh);
        return $dir."/".$file;
      }
      if (-d $dir."/".$f && $f ne $excludeDirName){
         my $subDirFile = $self->findFile($dir."/".$f,$file);
         if (defined($subDirFile)){
           closedir($dh);
           return $subDirFile;
         }
      }
   }
   closedir($dh);
   return undef;
}

=head3 getDirectorySize 

This method takes a directory path and determines
disk space consumed by files in this path.  This
method will IGNORE any symbolic links.  The method
returns a lot of data in separate variables.  The
last variable $error if set means there was a problem.
A value of undef in $error means we are good.

my ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error) = $f->getDirectorySize("/foo");

=cut

sub getDirectorySize {
    my $self = shift;
    my $path = shift;
    my $depth = shift;

    # this is a file just return
    if (-f $path){
        my $size = -s $path;
        return (1,0,0,$size,undef);
    }

    # if we reached a depth of 20 bail cause this is too deep and might hint
    # at a circular reference
    if (defined($depth) && $depth > 20){
        $self->{Logger}->error("Reached max directory depth of 20");
        return (0,0,0,0,"Reached max directory depth of 20");
    }    

    # increment path depth cause its not a file
    if (!defined($depth)){
      $depth = 1;
    }
    else {
      $depth++;
    }

    # this is a symlink invoke readlink and follow that path
    if (-l $path){
        $path = readlink($path);
        my ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error) = $self->getDirectorySize($path,$depth);
        $numSymLinks++;
        return ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error);
    }

    # this is a directory
    if (-d $path){
        if (!opendir(DIR,$path)){
           $self->{Logger}->error("Unable to open $path : $!");
           return (0,0,0,0,"Unable to open $path : $!");
        }
        my @files = grep(!/^\.\.?$/, readdir(DIR));
        closedir(DIR);
        my $numFiles = 0;
        my $numDirs = 0;
        my $numSymLinks = 0;
        my $sizeInBytes = 0;
        my $error = undef;
 
        my $totalFiles = 0;
        my $totalDirs = 1;
        my $totalSymLinks = 0;
        my $totalBytes = 0;

        for (my $x = 0; $x < @files; $x++){
            ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error) = $self->getDirectorySize($path."/".$files[$x],$depth);
	    $totalFiles += $numFiles; 
            $totalDirs += $numDirs;
            $totalSymLinks += $numSymLinks;
            $totalBytes += $sizeInBytes;
            if (defined($error)){
                return ($totalFiles,$totalDirs,$totalSymLinks,$totalBytes,$error);
            }
        }
	return ($totalFiles,$totalDirs,$totalSymLinks,$totalBytes,$error);
    }
    # this is not a file, directory or sym link so just ignore it
    return (0,0,0,0,undef);
}


#
# cleans up the path
# Got this method from Tim Warnock's script SRBupdate
#
sub standardizePath {
    my $self = shift;
    my $path = shift;
    
    if (!defined($path)){
        return undef;
    }

    #TODO FIX THIS WINDOWS HACK
    #if on windows do not standardize path
    if ($^O=~/Win/){
       return $path;
    }

    my @realPath = ();
    my @pathsplit = split('\/', $path);
    foreach ( @pathsplit ) {
        if (/^\.\.$/) {
            pop @realPath;
        } elsif (/^\.$/) {
            next;
        } elsif (/\w+/) {
            push @realPath, $_;
        }
    }
    my $returnPath = join "\/", @realPath;
    if ($returnPath eq ""){
        
        return "/";
    }

    return "/$returnPath";
}

=head3 touch

Creates empty file.  Returns 1 upon success, 0 otherwise.

=cut

sub touch {
    my $self = shift;
    my $path = shift;
   
    if (!open(HANDLE,">$path")){
        return 0;
    }
    close(HANDLE);
    return 1;
}


1;

__END__


=head1 AUTHOR

Panfish::FileUtil is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

