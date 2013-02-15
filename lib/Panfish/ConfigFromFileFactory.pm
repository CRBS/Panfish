package Panfish::ConfigFromFileFactory;

use strict;
use English;
use warnings;


=head1 SYNOPSIS
   
  Panfish::ConfigFromFileFactory Creates a Config object from a Configuration file

=head1 DESCRIPTION

 Given a Configuration file this object creates a Config object.

=head1 METHODS

=head3 new

Constructor which takes a FileReaderWriter object as
the first argument and optionally a Logger as the second argument.

Ex:

my $readerwriter = Panfish::FileReaderWriterImpl->new();
my $logger = Panfish::Logger->new();
my $f = Panfish::ConfigFromFileFactory->new($readerwriter,$logger);

=cut


sub new {
   my $class = shift;
   my $self = {
      Reader => shift,
      Logger => shift
   };

   die "Invalid FileReaderWriter object" unless $self->{Reader}->isa('Panfish::FileReaderWriter');

   my $blessedself = bless($self,$class);
   return $blessedself;
}


=head3 getConfig

Given a path to a file this method returns a Config object
derived from that file

=cut

sub getConfig {
    my $self = shift;
    my $configFile = shift;
   
    my $res = $self->{Reader}->openFile($configFile);

    if (defined($res)){
      # there was a problem opening the file let the caller
      # know by tossing back undef
      return undef;
    }
 
    my $trimParamName;
    my $val;
    my $config = undef;
    my $curLine = $self->{Reader}->read();
    while (defined($curLine)){
        chomp($curLine);
        if ($curLine!~/^#/){
            if ($curLine=~/^(.*)\s*=\s*(.*)$/){
                $trimParamName = $1;
                $val = $2;
                $trimParamName=~s/\s+$//;

                if (!defined($config)){
                  $config = Panfish::Config->new();
                }
                $config->setParameter($trimParamName,$val);
            }
        }
        $curLine = $self->{Reader}->read();
    }
    $self->{Reader}->close();
    return $config;
}


1;

__END__


=head1 AUTHOR

   Panfish::ConfigFromFileFactory is written by Chris Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut

