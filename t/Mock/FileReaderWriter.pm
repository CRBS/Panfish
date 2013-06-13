package Mock::FileReaderWriter;

use strict;
use English;
use warnings;

require Panfish::FileReaderWriter;
our @ISA = qw(Panfish::FileReaderWriter);

sub new {
   my $class = shift;
   my $self = {
     Read     => undef,
     Write    => undef,
     OpenFile => undef,
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

sub addReadResult {
   my $self = shift;
   my $result = shift;
   push(@{$self->{Read}},$result);
}

sub read {
  my $self = shift;
  return pop(@{$self->{Read}});
}

sub write {
  my $self = shift;
  my $data = shift;
  push(@{$self->{Write}},$data);
  return undef;
}

sub getWrites {
   my $self = shift;
   return @{$self->{Write}};
}

sub addOpenFileResult {
   my $self = shift;
   my $file = shift;
   my $result = shift;

   push (@{$self->{OpenFile}->{$file}},$result);
   return;
}

sub openFile {
   my $self = shift;
   my $file = shift;

   return pop(@{$self->{OpenFile}->{$file}});
}

sub close{
   my $self = shift;
   return;
}


1;

__END__
