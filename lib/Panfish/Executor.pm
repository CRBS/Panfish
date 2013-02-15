package Panfish::Executor;

use strict;
use English;


=head1 NAME

Panfish::Executor - Defines an interface containing methods to run a 
                   command.

=head1 SYNOPSIS

To implement this interface include the following in the module.

  require Panfish::Executor;
  our @ISA = qw(Panfish::Executor);

=head1 DESCRIPTION
	       
This module defines an interface for objects that run 
commands via executeCommand() method.  

=head1 METHODS

=head3 getCommand

  Gets the last command run

=cut

sub getCommand {
    die("Method Panfish::Executor::getCommand() not defined\n");
}

=head3 getOutput

  Gets the output of the last run command or empty string if no 
  commands have been run.

=cut

sub getOutput {
    die("Method Executor::getOutput() not defined\n");
}

=head3 getExitCode
  
  Gets the exit code of the last run command or -1 if no commands
  have been run.
  $exitcode = $exec->getExitCode();

=cut

sub getExitCode {
    die("Method Executor::getExitCode() not defined\n");
}

=head3 executeCommand

  my $exitcode = $fbs->executeCommand("/bin/ls",10);

  Executes the command passed to it. The first argument
  '/bin/ls' shown below is the command to run.  The second
  argument which is optional is the amount of time in seconds to let
  the process run before killing it.  After running this command
  the methods getOutput(),getCommand(), getExitCode() will be
  set with the results of invoking this process.

=cut

sub executeCommand {
    die("Method Executor::executeCommand() not defined\n");
}

1;

__END__

=head1 AUTHOR
   Executor is written by Christopher Churas E<lt>churas@ncmir.ucsd.eduE<gt>

=cut
