package Panfish::FileReaderWriterImpl;

use strict;
use English;


require Panfish::FileReaderWriter;

our @ISA = qw(Panfish::FileReaderWriter);

=head1 NAME

Panfish::FileReaderImpl - Reads contents of files

=head1 SYNOPSIS

To use include

use Panfish::FileReaderImpl;


=head1 DESCRIPTION
	       
Offers methods to read contents of a file
one line at a time.

=head1 METHODS



=head3 new

Constructor.  Can optionally take a Panfish::Logger object 

my $fr = Panfish::FileReaderImpl->new();

or

my $fr = Panfish::FileReaderImpl->new(Panfish::Logger->new());

=cut

sub new {
    my $class = shift;
    my $self = {
        Logger => shift,
        FilePath => undef,
        FileHandle => undef,
    };
    my $blessedSelf = bless($self,$class);
    return $blessedSelf;
}



=head3 close

Closes the currently opened file. 

$fr->close();

=cut

sub close {
    my $self = shift;

    if (defined($self->{FileHandle}) && 
        defined($self->{FilePath})){

       close($self->{FileHandle});
       $self->{FileHandle} = undef;
       $self->{FilePath} = undef;
    }
}

=head3 read

Reads next line from file or undef if no data to read.

$fr->read();


=cut

sub read {
    my $self = shift;

    if (defined($self->{FileHandle}) && 
        defined($self->{FilePath})){

        return readline($self->{FileHandle});
    }
    return undef;
}


=head3 write

Writes to file.  NOTE: file handle must have been opened in writable mode
for this to work

$fr->write("blah blah");

=cut

sub write {
    my $self = shift;
    my $dataToWrite = shift;
    if (defined($self->{FileHandle}) &&
        defined($self->{FilePath}) &&
        defined($dataToWrite)){
        my $fh = $self->{FileHandle};
        print $fh $dataToWrite;
        return undef;
    }
}


=head3 
  
Opens the file passed in returning undef upon success or text
if there was an error with information on the problem.

$fr->openFile("/home/foo/somefile.txt");

=cut

sub openFile {
    my $self = shift;

    $self->{FilePath} = shift;

    if (!defined($self->{FilePath})){
        my $errmsg = "FilePath passed in is null";
	if (defined($self->{Logger})){
            $self->{Logger}->error($errmsg);
        }       
    
        return $errmsg;
    }
    if (!open($self->{FileHandle},$self->{FilePath})){
        
        my $errmsg = "Unable to open: ".$self->{FilePath}." : $!";
        if (defined($self->{Logger})){
            $self->{Logger}->error($errmsg);
        }  

  	$self->{FileHandle} = undef;
        $self->{FilePath} = undef;

        return $errmsg;
    }
    return undef;
}


1;

__END__

=head1 AUTHOR
   FileReaderWriterImpl is written by Christopher Churas E<lt>churas@ncmir.ucsd.eduE<gt>

=cut
