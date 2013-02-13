package Panfish::ForkExecutor;



use POSIX ":sys_wait_h";
use strict;
use English;
use warnings;
use Fcntl;

# this implements the Executor interface so add it to @ISA
require Panfish::Executor;
our @ISA = qw(Panfish::Executor);


=head1 NAME

Panfish::ForkExecutor - Runs commands passed to it by first spawning a 
                       child process to run the command. 

=head1 SYNOPSIS

  require ForkBSExecutor;
  my $fbs = BSwrapper::ForkBSExecutor->new();

  $fbs->setTimeout(60);  
  $exitcode = $fbs->executeCommand("/bin/ls /home/foo",2);		   
  my $com = $fbs->getCommand();					   
  my $output = $fbs->getOutput();
  my $exitcode = $fbs->getOutput();
					   
					   
=head1 DESCRIPTION

This module defines an object that runs commands via executeCommand()
method.  The method works by forking a child process that runs the
command while the parent process gathers the exitcode and output of
the child process.  Also if the command in the child process exceeds
the time set via executeCommand parameters or if that is unset by the
setTimeout method then the child process is killed.  
					   
=head1 METHODS


=head3 new

  Creates new Panfish::ForkExecutor object

  my $exec = Panfish::ForkExecutor->new();

=cut

sub new {
    my $class = shift;
    my $self = {
	Command => "",
	Output => "",
	ExitCode => -1
	};
    return bless ($self,$class);
}

=head3 setTimeout

  Sets the timeout in seconds a job is allowed to run before being 
  killed for the executeCommand method.  This can be overwridden by 
  passing a timeout to executeCommand() method.

  my $exitcode = $exec->getExitCode();

=cut

sub setTimeout {
    my $self = shift;
    return $self->{TimeOut} = shift;
}

=head3 getCommand

  Gets the last command run as string

  my $command = $exec->getCommand();

=cut

sub getCommand {
    my $self = shift;
    return $self->{Command};
}

=head3 getOutput

  Gets the output of the last run command as string.
  This includes stderr.
  
  my $output = $exec->getOutput();

=cut

sub getOutput {
    my $self = shift;
    return $self->{Output};
}

=head3 getExitCode

  Gets the exit code of the last run command

  my $exitcode = $exec->getExitCode();

=cut

sub getExitCode {
    my $self = shift;
    return $self->{ExitCode};
}

=head3 executeCommand

  Executes command passed to it.  The program forks and watches
  the child process to make sure it doesnt run beyond the timeout
  set via this method or if not set the timeout set for this object
  via setTimeout() method.  This method returns exit code of 
  command or -1 if there was an error.

  
  my $exitcode = $exec->executeCommand($cmd,$timeout,$resetOnOutput);
 
    $cmd - The command to run Ex: /bin/ls -la
    $timeout - Timeout in seconds to let job run.  Pass undef 
                    to use default timeout set via setTimeout()
		    method. Ex: 10
                    
    $resetOnOutput -If output is seen from command reset the
                    clock that is used for determining if a
                    job has exceeded runtime. Ex: 1
	            (set to 1 to enable)


=cut

sub executeCommand {
    my $self = shift;
    my $command = shift;
    my $timeout = shift;
    my $resetTimeoutOnOutput = shift;

    
    
    $self->{ExitCode} = -1;
    $self->{Output} = "";
    if (!defined($command)){
	$self->{Command} = undef;
	$self->{Output} = undef;
	$self->{ExitCode} = -1;
	return -1;
    }

    $self->{Command} = $command;

    if (!defined($resetTimeoutOnOutput)){
	$resetTimeoutOnOutput = 0;
    }

    #open -| is the same as fork but with the benefit of being able to
    #obtain the output of the child
    #the reason we are forking is because we want to be able to kill a
    #process that is taking too long
    my $pid = open(KID_TO_READ,"-|");

    
    #checking the value of $pid tells is if we are the parent or the
    #child.  If $pid is 0 we are the child and if $pid > 0 we are the parent
    # I should really check that $pid is > 0 cause there is a chance
    #that there is not enough resources and the fork failed
    if ($pid == 0){
	if (!open(MYJOB,"$command |")){
	    exit 1;
	}
	while (<MYJOB>){
	    print $_;
	}
	close(MYJOB) || exit 1;
	#child exits
	exit 0;
    }

    #I am the parent.  wait in a while loop for process to end
    # if its taking too long kill the process and set the appropriate
    # error codes


    my $buffer;
    my $BUFSIZ = 256;
    my $flags = 0;

    #this stuff below allows us to do non blocking io which is important if the output
    #is big
    fcntl(KID_TO_READ,F_GETFL,$flags) || die "Couldn't get flags for KID_TO_READ $!\n";
    $flags |= O_NONBLOCK;
    fcntl(KID_TO_READ,F_SETFL,$flags) || die "Couldn't set flags for KID_TO_READ $!\n";

    my $starttime = time();
    my $curtime;
    while ($pid != waitpid($pid,WNOHANG)){
	$curtime = time();
	if (defined($timeout) && ($curtime - $starttime) > $timeout){
	    #this is taking too long kill the children
	    
	    $self->killChildren($pid);
	    kill('KILL',$pid);
	    $self->{ExitCode} = -999;
	    $self->{Output} = "Runtime Exceeded $timeout seconds process killed by parent";
	    last;
	}

	#if CommandDecider is defined see if job should be killed
	
	my $rv = sysread(KID_TO_READ,$buffer,$BUFSIZ);
	if (defined($rv) && $rv > 0){

	    $self->{Output} .= $buffer;
	    
	    #reset the clock if we saw output and $resetTimeoutOnOutput is set to 1
	    if ($resetTimeoutOnOutput == 1){
		$starttime = $curtime;
	    }
	}
	else {
	    #if we dont have any output sleep for a tenth of a second
	    #to yield the cpu
	    select(undef,undef,undef,0.1);
	}
    }

    #get the output from the child process If I did not kill it
    if ($self->{ExitCode} != -999){
	#the line below undef $/; lets me dump the entire contents of the child
	#output into the scalar $self->{Output}

	$self->{ExitCode} = $?;
	
	my $rv = sysread(KID_TO_READ,$buffer,$BUFSIZ);

	while (!defined($rv) || $rv != 0){
	    if (defined($rv) && $rv > 0){

		$self->{Output} .= $buffer;
	    }
	    $rv = sysread(KID_TO_READ,$buffer,$BUFSIZ);
	}
    }
    close(KID_TO_READ);

    return $self->{ExitCode};
}


# This is a recursive method that kills all the children without mercy.
# Am I not merciful
sub killChildren {
    my $self = shift;
    my $processid = shift;
    my $x;
    my @pidsplit;
    
    my $psout=`ps x -o pid,ppid,command`;

    my @lines = split('\n',$psout);

    for ($x = 1; $x < @lines; $x++){
	@pidsplit = split(' ',$lines[$x]);
	if ($pidsplit[1] eq $processid){
	    $self->killChildren($pidsplit[0]);
	    kill('KILL',$pidsplit[0]);
	}
    }
    return;
}

1;

__END__

=head1 AUTHOR
   Panfish::ForkExecutor is written by 
   Chris Churas E<lt>churas@ncmir.ucsd.eduE<gt>

=cut
