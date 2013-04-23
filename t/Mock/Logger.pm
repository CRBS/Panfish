package Mock::Logger;

use strict;
use English;
use warnings;


sub new {
   my $class = shift;
   my $self = {
     Logs => undef,
     DebugEnabled => undef
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

sub setIsDebugEnabled {
   my $self = shift;
   $self->{DebugEnabled} = shift;
}

sub info {
  my $self = shift;
   my $val = shift;
   push(@{$self->{Logs}},"INFO ".$val);

}

sub debug {
  my $self = shift;
   my $val = shift;
   push(@{$self->{Logs}},"DEBUG ".$val);

}

sub warn {
  my $self = shift;
   my $val = shift;
   push(@{$self->{Logs}},"WARN ".$val);

}

sub error {
  my $self = shift;
   my $val = shift;
   push(@{$self->{Logs}},"ERROR ".$val);

}

sub fatal {
   my $self = shift;
   my $val = shift;
   push(@{$self->{Logs}},"FATAL ".$val);
}

sub isDebugEnabled {
   my $self = shift;
   return $self->{DebugEnabled};
}

sub getLogs {
  my $self = shift;
  if (!defined($self->{Logs})){
     return undef;
  }
  return @{$self->{Logs}};
}

1;

__END__
