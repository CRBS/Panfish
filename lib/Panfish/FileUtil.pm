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

1;

__END__


=head1 AUTHOR

Panfish::FileUtil is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

