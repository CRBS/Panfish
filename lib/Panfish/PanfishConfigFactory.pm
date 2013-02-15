package Panfish::PanfishConfigFactory;

use strict;
use English;
use warnings;
use Panfish::ConfigFromFileFactory;
use Panfish::PanfishConfig;
use Panfish::Config;

use FindBin qw($Bin);

=head1 SYNOPSIS
   
  Panfish::PanfishConfigFactory Creates a PanfishConfig object

=head1 DESCRIPTION

This object creates a PanfishConfig object by looking for a 
configuration object in the following places in this order:

$BIN/panfish.config

=head1 METHODS

=head3 new

Constructor which takes a FileReaderWriter object as
the first argument and optionally a Logger as the second argument.

Ex:

my $reader = Panfish::FileReaderWriterImpl->new();
my $logger = Panfish::Logger->new();
my $f = Panfish::PanfishConfigFactory->new($reader,$logger);

=cut


sub new {
   my $class = shift;
   my $reader = shift;
   my $self = {
      ConfigFactory => undef,
      Logger => shift,
      PANFISH_CONFIG => "panfish.config"
   };

   die "Invalid FileReaderWriter object" unless $reader->isa('Panfish::FileReaderWriter');

   $self->{ConfigFactory} = Panfish::ConfigFromFileFactory->new($reader,$self->{Logger});

   my $blessedself = bless($self,$class);
   return $blessedself;
}


=head3 getPanfishConfig

Returns PanfishConfig object by looking for a config file in a
few key places.

=cut

sub getPanfishConfig {
    my $self = shift;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Attempting to parse config from: $Bin/".$self->{PANFISH_CONFIG});
    }

    my $config = $self->{ConfigFactory}->getConfig("$Bin/".$self->{PANFISH_CONFIG});

    if (!defined($config)){
      return undef;
    }

    return Panfish::PanfishConfig->new($config);
    
}


1;

__END__


=head1 AUTHOR

   Panfish::PanfishConfigFactory is written by Chris Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut

