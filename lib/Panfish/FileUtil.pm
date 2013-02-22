package Panfish::FileUtil;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
  Panfish::FileUtil -- Set of File Utilities

=head1 DESCRIPTION

Set of File utility methods

=head1 METHODS

=head3 new

Creates new instance of Job object

my $job = Panfish::Job->new()

=cut

sub new {
   my $class = shift;
   my $self = {
     Logger          => shift
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
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
   
   if (!defined($dir)){
      if (defined($self->{Logger})){
         $self->{Logger}->debug("Dir is undefined");
      }
      return undef;
   }
   if (!defined($file)){
      if (defined($self->{Logger})){
         $self->{Logger}->debug("File is undefined");
      }
      return undef;
   }
   
   my $dh;

   if (!opendir($dh,$dir)){
      return "Unable to open directory $dir : $!";
   }
   
   if (defined($self->{Logger})){
      $self->{Logger}->debug("Examining directory: $dir");
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
      if (-d $dir."/".$f){
         if (defined($self->{Logger})){
            $self->{Logger}->debug("\t\t$f is a directory examining");
         } 
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

    # this is a file just return
    if (-f $path){
        my $size = -s $path;
        return (1,0,0,$size,undef);
    }
    
    # this is a symlink
    if (-l $path){
        return (0,0,1,0,undef);
    }

    # this is a directory
    if (-d $path){
        if (!opendir(DIR,$path)){
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
            ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error) = $self->getDirectorySize($path."/".$files[$x]);
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




1;

__END__


=head1 AUTHOR

Panfish::FileUtil is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

