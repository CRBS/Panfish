package Mock::Executor;

use strict;
use English;
use warnings;

require Panfish::Executor;

our @ISA = qw(Panfish::Executor);

sub new {
    my $class = shift;
    my $self = {
	Command => undef,
	Output => undef,
	ExitCode => undef,
	OutputHash => undef,
	ExitCodeHash => undef,
	TimeOutHash => undef,
	ResetTimeOnOutputHash => undef,
	CommandCount => 0
	};
    return bless ($self,$class);
}


sub add_expected_result {
    my $self = shift;
    my $command = shift;
    my $output = shift;
    my $exitcode = shift;
    my $timeout = shift;
    my $resettimeout = shift;
    push(@{$self->{OutputHash}->{$command}},$output);
    push(@{$self->{ExitCodeHash}->{$command}},$exitcode);
    push(@{$self->{TimeOutHash}->{$command}},$timeout);
    push(@{$self->{ResetTimeOnOutputHash}->{$command}},$resettimeout);
    $self->{CommandCount}++;
}

sub getCommand {
    my $self = shift;
    return $self->{Command};
}

sub getOutput {
    my $self = shift;
    return $self->{Output};
}

sub getExitCode {
    my $self = shift;
    return $self->{ExitCode};
}

sub getCommandCount {
    my $self = shift;
    return $self->{CommandCount};
}

#
# Executes command directly using backticks.  Should replace this
# with a version that does fork exec with a timeout feature
#
sub executeCommand {
    my $self = shift;
    my $command = shift;
    my $timeout = shift;
    my $resetimeout = shift;
    
    
    if (!defined($command)){
	$self->{Command} = undef;
	$self->{Output} = undef;
	$self->{ExitCode} = -1;
	return -1;
    }
    $self->{Command} = $command;

    if (!defined($self->{OutputHash}->{$command}) ||
	!defined($self->{ExitCodeHash}->{$command})){
	Test::More::fail("$command..............Not defined\n");
	$self->{Command} = $command;
	$self->{Output} = "COMMAND NOT DEFINED IN MOCK OBJECT";
	$self->{ExitCode} = -1;
	
	return -1;
    }

    
    $self->{Output} = pop(@{$self->{OutputHash}->{$command}});
    $self->{ExitCode} = pop(@{$self->{ExitCodeHash}->{$command}});

    $self->{CommandCount}--;
    
    my $checktimeout = pop(@{$self->{TimeOutHash}->{$command}});
    if (defined($checktimeout) && defined($timeout)){
	if (abs ($checktimeout - $timeout) > 1){
	    Test::More::fail("TIMEOUTS DO NOT MATCH $checktimeout $timeout\n");
	    return -1;
	}
    }
    if (!defined($self->{ExitCode})){
	Test::More::fail("Exit is not defined $command\n");
    }
    
    my $checkreset = pop(@{$self->{ResetTimeOnOutputHash}->{$command}});
    if (defined($checkreset)){
	if (!defined($resetimeout)){
	    Test::More::fail("Expected reset timeout value for command: $command");
	}
	else {
	    if ($checkreset != $resetimeout){
		Test::More::fail("Reset time out values do not match Expect: $checkreset and got: $resetimeout");
	    }
	}
    }
    elsif (defined($resetimeout)) {
	Test::More::fail("Didnt expect reset timeout for $command");
    }
    
    return $self->{ExitCode};
}

sub executeCommandWithRetry {
   my $self = shift;
   my $numRetries = shift;
   my $retrySleep = shift;
   my $command = shift;
   my $timeout = shift;
   my $resetTimeoutOnOutput = shift;

   return $self->executeCommand($command,$timeout,$resetTimeoutOnOutput);
}



1;

__END__
