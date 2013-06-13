package Panfish::SSHExecutor;



use POSIX ":sys_wait_h";
use strict;
use English;
use warnings;
use Fcntl;

# this implements the Executor interface so add it to @ISA
require Panfish::Executor;
our @ISA = qw(Panfish::Executor);


=head1 NAME

Panfish::SSHExecutor - Runs commands passed in through ssh.

=head1 SYNOPSIS

  require SSHExecutor;
  my $executor = Panfish::ForkExecutor->new();
  my $logger = Panfish::Logger->new();
  my $c = Panfish::PanfishConfig->new();
  my $fbs = Panfish::SSHExecutor->new($executor,$c,$logger);

  $fbs->setTimeout(60);  
  $fbs->setCluster("gordon_shadow.q");
  $fbs->setStandardInputCommand("echo -e \"blah\\nfoo\\n"");
  $exitcode = $fbs->executeCommand("/bin/ls /home/foo",2);		  
  my $com = $fbs->getCommand();					   
  my $output = $fbs->getOutput();
  my $exitcode = $fbs->getOutput();
					   
					   
=head1 DESCRIPTION

This module defines an object that runs commands via executeCommand()
method through ssh.  The B<setCluster> method defines the remote host
by looking up the actual host in the B<PanfishConfig> set in the
constructor.  The B<Executor> passed in via the constructor is used
to invoke ssh.
					   
=head1 METHODS


=head3 new

  Creates new Panfish::SSHExecutor object

  my $executor = Panfish::ForkExecutor->new();
  my $config = Panfish::PanfishConfig->new();

  my $exec = Panfish::SSHExecutor->new($executor,$config,Panfish::Logger->new());

=cut

sub new {
    my $class = shift;
    my $self = {
        Config        => shift,
        Executor      => shift,
        Logger        => shift,
        Host          => "",
        StdInCommand  => "",
        SSHCommand    => "/usr/bin/ssh",
        UseSSH        => 1
	};
    return bless ($self,$class);
}

=head3 setCluster

Sets the cluster that this object should connect to via ssh.

=cut

sub setCluster {
    my $self = shift;
    my $cluster = shift;

    if (!defined($self->{Config})){
        return "Config not set...";
    }

    $self->{Host} = $self->{Config}->getHost($cluster); 
    if (!defined($self->{Host})){
        return "Unable to get host for cluster:  $cluster";
    }
    return undef;
}

=head3 getCommand

  Gets the last command run as string

  my $command = $exec->getCommand();

=cut

sub getCommand {
    my $self = shift;
    return $self->{Executor}->getCommand();
}

=head3 getOutput

  Gets the output of the last run command as string.
  This includes stderr.
  
  my $output = $exec->getOutput();

=cut

sub getOutput {
    my $self = shift;
    return $self->{Executor}->getOutput();
}

=head3 getExitCode

  Gets the exit code of the last run command

  my $exitcode = $exec->getExitCode();

=cut

sub getExitCode {
    my $self = shift;
    return $self->{Executor}->getExitCode();
}


=head3 setStandardInputCommand

Sets command whose output will be piped to
standard in off ssh command invoked by
executeCommand method.

=cut

sub setStandardInputCommand {
    my $self = shift;

    $self->{StdInCommand} = shift;

    return undef;
}

=head3 enableSSH 


=cut

sub enableSSH {
    my $self = shift;
    $self->{UseSSH} = 1;
}

=head3 disableSSH 


=cut

sub disableSSH {
    my $self = shift;
    $self->{UseSSH} = 0;
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
    
    my $cmd = $self->_buildCommandToExecute($command);

    return $self->{Executor}->executeCommand($cmd,$timeout,$resetTimeoutOnOutput);
}


sub _buildCommandToExecute {
   my $self = shift;
   my $command = shift;
 
   if (!defined($command)){
     return "";
   }

   my $cmd = "";

   # see if any command neads to be set before the ssh command
   if (defined($self->{StdInCommand}) &&
        $self->{StdInCommand} ne ""){

        $cmd = $self->{StdInCommand}." | ";
    }
 
    # only set the ssh stuff if the user wants it.
    if ($self->{UseSSH} == 1){
        $cmd .= $self->{SSHCommand}." ".$self->{Host}." ";
    }

    # finally append the command
    $cmd .= $command;
    return $cmd;
}

=head3 executeCommandWithRetry 

Executes command with automatic retry and sleep between retries if command fails
with non zero exit code

my $exitcode = $exec->executeCommandWithRetry($numretries,$retrysleep,$cmd,$timeout,$resetOnOutput);

=cut

sub executeCommandWithRetry {
   my $self = shift;
   my $numRetries = shift;
   my $retrySleep = shift;
   my $command = shift;
   my $timeout = shift;
   my $resetTimeoutOnOutput = shift;

   my $cmd = $self->_buildCommandToExecute($command);
   return $self->{Executor}->executeCommandWithRetry($numRetries,$retrySleep,$cmd,$timeout,$resetTimeoutOnOutput);
}


1;

__END__

=head1 AUTHOR

Panfish::SSHExecutor is written by Christopher Churas <churas@ncmir.ucsd.edu>

=cut
