package Panfish::PanfishConfigFactory;

use strict;
use English;
use warnings;
use Panfish::ConfigFromFileFactory;
use Panfish::PanfishConfig;
use Panfish::Config;
use Panfish::FileUtil;
use Panfish::Logger;
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

my $logger = Panfish::Logger->new();
my $reader = Panfish::FileReaderWriterImpl->new($logger);
my $fUtil = Panfish::FileUtil->new($logger);
my $f = Panfish::PanfishConfigFactory->new($reader,$fUtil,$logger);

=cut


sub new {
   my $class = shift;
   my $reader = shift;
   my $self = {
      FileUtil      => shift,
      Logger        => shift,
      ConfigFactory => undef,
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

    my @pathList;
    if ( $ENV{"PANFISH_CONFIG"}){
       push(@pathList,$ENV{"PANFISH_CONFIG"});
    }
    push(@pathList,$ENV{"HOME"}."/.".$self->{PANFISH_CONFIG});
    push(@pathList,"$Bin/../etc/".$self->{PANFISH_CONFIG});
    push(@pathList,"$Bin/".$self->{PANFISH_CONFIG});
    push(@pathList,"/etc/".$self->{PANFISH_CONFIG});

    for (my $x = 0; $x < @pathList; $x++){
       my $config = $self->_getPanfishConfigFromPath($pathList[$x]);
       if (defined($config)){

          # if we are given a PanfishConfig, just set the config
          # into that object and return it
          if (defined($existingConfig)){
             $existingConfig->setConfig($config);
             return $existingConfig;
          }
          return Panfish::PanfishConfig->new($config);
       }
    }

    $self->{Logger}->error("Unable to load config from any of these locations: ".join(', ',@pathList));
    return undef;
}

sub _getPanfishConfigFromPath {
    my $self = shift;
    my $path = shift;
    
    if (!defined($path)){
       return undef;
    }

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Attempting to parse config from: $path");
    }

    if (! $self->{FileUtil}->runFileTest("-e",$path)){
        return undef;
    }

    return $self->{ConfigFactory}->getConfig($path);
}


1;

__END__


=head1 AUTHOR

   Panfish::PanfishConfigFactory is written by Chris Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut

