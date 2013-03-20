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

   $self->{ConfigFactory} = Panfish::ConfigFromFileFactory->new($reader,$self->{Logger});

   my $blessedself = bless($self,$class);
   return $blessedself;
}


=head3 getPanfishConfig

Returns PanfishConfig object by looking for a config file in a
few key places.  This method will create a new PanfishConfig object
unless a PanfishConfig object is passed into the method, in which case
 the configuration is adjusted in the PanfishConfig object passed in and
is returned to the caller

=cut

sub getPanfishConfig {
    my $self = shift;
    my $existingConfig = shift;
   
    # Try loading config in Bin/../etc 
    my $config = $self->_getPanfishConfigFromPath("$Bin/../etc/".$self->{PANFISH_CONFIG});
  
    if (!defined($config)){
        # Try loading config in Bin/
        $config = $self->_getPanfishConfigFromPath("$Bin/".$self->{PANFISH_CONFIG});
    }

    if (!defined($config)){
       $self->{Logger}->error("Unable to load config from $Bin/ or $Bin/../etc");
       return undef;
    }

   
    # if we are given a PanfishConfig, just set the config into that object and return it
    if (defined($existingConfig)){
       $existingConfig->setConfig($config);
       return $existingConfig;
    }

    return Panfish::PanfishConfig->new($config);
    
}

sub _getPanfishConfigFromPath {
    my $self = shift;
    my $path = shift;

    if (! -e $path){
        return undef;
    }

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Attempting to parse config from: $path");
    }

    my $config = $self->{ConfigFactory}->getConfig($path);

    return $config;
}


1;

__END__


=head1 AUTHOR

   Panfish::PanfishConfigFactory is written by Chris Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut

