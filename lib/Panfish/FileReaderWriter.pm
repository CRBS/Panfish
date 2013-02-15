package Panfish::FileReaderWriter;

use strict;
use English;


=head1 NAME

Panfish::FileReaderWriter - Defines an interface to read/write contents of a file

=head1 SYNOPSIS

To implement this interface include the following in the module.

require Panfish::FileReaderWriter;
our @ISA = qw(Panfish::FileReaderWriter);

=head1 DESCRIPTION
	       
This module defines an interface to read contents of a file
one line at a time.

=head1 METHODS

=head3 close

Closes the currently opened file. 

$fr->close();

=cut

sub close {
    die("Method Executor::close() is abstract.\n");
}

=head3 read

Reads next line from file or undef if no data to read.

$fr->read();


=cut

sub read {
    die("Method FileReader::read() is abstract.\n");
}


=head3 write

Writes value passed in to file handle.
NOTE:  Caller must have opened file first in a writable mode
otherwise who knows what happens here

=cut

sub write {
   die("Method FileReaderWriter::write() is abstract.\n");
}
  
=head3 openFile

Opens the file passed in returning undef upon success or text
if there was an error with information on the problem.

$fr->openFile("/home/foo/somefile.txt");

=cut

sub openFile {
    die("Method FileReader::openFile() is abstract.\n");
}


1;

__END__

=head1 AUTHOR
   Executor is written by Christopher Churas E<lt>churas@ncmir.ucsd.eduE<gt>

=cut
