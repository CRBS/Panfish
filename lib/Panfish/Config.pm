package Panfish::Config;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
  Panfish::Config -- Represents a hash of key value pairs found in configruations

=head1 DESCRIPTION

This object wraps a hash of key/value pairs that represent
the various configuration and job files.

=head1 METHODS

=head3 new

Creates new instance of Config object

my $foo = Panfish::Config->new()

=cut

sub new {
   my $class = shift;
   my $self = {
     Param => undef,
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 copy

Makes a copy of this object

=cut

sub copy {
  my $self = shift;
  
  my $configCopy = Panfish::Config->new();
  my $paramNames = $self->getParameterNames();

  if (!defined($paramNames)){
    return $configCopy;
  }

  for (my $x = 0; $x < @$paramNames; $x++){
    $configCopy->setParameter(${$paramNames}[$x],
                              $self->getParameterValue(${$paramNames}[$x]));
  }
  return $configCopy;
}

=head3 load

Updates this config object with data
from Config object passed in

=cut

sub load {
  my $self = shift;
  my $config = shift;

  if (!defined($config)){
    return "Config passed in is not defined";
  }

  my $paramNames = $config->getParameterNames();

  # nothing to do
  if (!defined($paramNames)){
    return undef;
  }

  for (my $x = 0; $x < @$paramNames; $x++){
    $self->setParameter(${$paramNames}[$x],
                        $config->getParameterValue(${$paramNames}[$x]));
  }
  return undef;
}

=head3 setParameter

Sets a new parameter with key and value.

$foo->setParameter("somekey","someval");

=cut

sub setParameter {
  my $self = shift;
  my $attribName = shift;
  my $attribValue = shift;
  $self->{Param}->{$attribName} = $attribValue;
  return undef;
}

=head3 getParameterNames

Returns an array of all the parameter key names.

my @keys = $foo->getParameterNames();

=cut

sub getParameterNames {
  my $self = shift;
  if (!defined($self->{Param})){
   return undef;
  }
  my @keylist = keys(%{$self->{Param}}); 
  return \@keylist;
}

=head3 getParameterValue

Gets value for parameter key passed in attributeName.  If value is undef for key
then attributeDefault is returned.  If attributeDefault is not set then in this case undef
is returned

my $res = $foo->getParameterValue("somekey","defaultval");


=cut

sub getParameterValue {
  my $self = shift;
  my $attribName = shift;
  my $attribDefault = shift;

  if (!defined($attribName)){
    return undef;
  }

  my $res = $self->{Param}->{$attribName};

  #if value for attribName is undef then use the default value passed in by caller
  if (!defined($res) && defined($attribDefault)){
     $res = $attribDefault;
  }
  return $res;
}

=head3 getAllSetValues

This method returns a string with all values loaded in object

Output string contains:
key=value<newline>

 
Where key's are sorted alphabetically

my $res = $foo->getAllSetValues();

=cut

sub getAllSetValues {
  my $self = shift;
  
  my $keylist = $self->getParameterNames();
  if (!defined($keylist)){
    return undef;
  }
  my @sortedkeys = sort { $a cmp $b} @$keylist;
  my $key;
  my $resStr = "";
  foreach $key (@sortedkeys){
     $resStr .= $key."=".$self->getParameterValue($key)."\n";
  }
  return $resStr;
}

1;

__END__


=head1 AUTHOR

Panfish::Config is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

