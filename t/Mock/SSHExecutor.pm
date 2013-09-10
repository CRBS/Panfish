package Mock::SSHExecutor;

use strict;
use English;
use warnings;


sub new {
   my $class = shift;
   my $self = {
     SetStandardInputCommandCallCount => 0,
     ExecuteCommandWithRetry => undef
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}

sub setStandardInputCommand {
   my $self = shift;
   my $val = shift;
   $self->{SetStandardInputCommandCallCount}++;
}

sub getSetStandardInputCommandCallCount {
   my $self = shift;
   return $self->{SetStandardInputCommandCallCount};
}

sub enableSSH {
    my $self = shift;
}

sub disableSSH {
    my $self = shift;
}

sub setCluster {
    my $self = shift;
    my $cluster = shift;
}


sub addExecuteCommandWithRetryResult {
       my $self = shift;
    my $retryCount = shift;
    my $retrySleep = shift;
    my $command = shift;
    my $timeout = shift;
    my $resetTimeoutOnOutput = shift;
    my $result = shift;

    push(@{$self->{ExecuteCommandWithRetry}->{$command}},$result);
}

sub executeCommandWithRetry {
    my $self = shift;
    my $retryCount = shift;
    my $retrySleep = shift;
    my $command = shift;
    my $timeout = shift;
    my $resetTimeoutOnOutput = shift;
    return pop(@{$self->{ExecuteCommandWithRetry}->{$command}});
}

1;

__END__
