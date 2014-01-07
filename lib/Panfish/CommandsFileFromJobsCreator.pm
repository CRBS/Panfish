package Panfish::CommandsFileFromJobsCreator;



use strict;
use English;
use warnings;

=head1 NAME

Panfish::CommandsFileFromJobsCreator -- Creates Psub file given a list of jobs

=head1 SYNOPSIS

  use Panfish::CommandsFileFromJobsCreator;
  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,
                                $fileutil,$writer,$logger);

  my ($error) = $cmdCreator->create($cluster,\@jobs);
  					   
					   
=head1 DESCRIPTION

Creates Commands file given a list of jobs.
					   
=head1 METHODS


=head3 new

  Creates new Panfish::CommandsFileFromJobsCreator

  my $sbatchParser = Panfish::CommandsFileFromJobsCreator->new();

=cut

sub new {
  my $class = shift;
  my $self = {
      Config              => shift,
      FileUtil            => shift,
      Writer              => shift,
      Logger              => shift
  };
  return bless ($self,$class);
}

=head3 create

Creates Commands file given cluster and reference to an array
of Jobs.

my ($error) = $cmdCreator->create("foo.q",\@jobs);

=cut

sub create {
  my $self = shift;
  my $cluster = shift; 
  my $jobsArrayRef = shift;

  if (!defined($cluster)){
    return "Cluster not defined";
  }

  if (!defined($jobsArrayRef) || @{$jobsArrayRef}<=0){
    return "No jobs to generate a Commands file for";
  }

  my $commandFile = $self->_getCommandFile($cluster,${$jobsArrayRef}[0]);

  if (!defined($commandFile)){
    return "Unable to get Command File";
  }

  $self->{Logger}->debug("Creating command file: $commandFile");

  my $res = $self->{Writer}->openFile(">$commandFile");
  if (defined($res)){
    $self->{Logger}->error("There was a problem opening file: ".
                           $commandFile);
    return "Unable to open file $commandFile";
  }

  for (my $x = 0; $x < @{$jobsArrayRef}; $x++){

    my $job = ${$jobsArrayRef}[$x];
    if (!defined($job)){
      $self->{Logger}->error("Job # $x pulled from array is not defined. wtf");
      return "Undefined job found";
    }
    $self->{Writer}->write($job->getCommand()."\n");
    $job->setCommandsFile($commandFile);
  }
  $self->{Writer}->close();
  return undef;
}

sub _getCommandFile {
  my $self = shift;
  my $cluster = shift;
  my $job = shift;

  if (!defined($job->getCurrentWorkingDir())){
    $self->{Logger}->error("Current working directory not defined for job");
    return undef;
  }
  
  my $commandDir = $job->getCurrentWorkingDir()."/".$cluster;

  $self->{Logger}->debug("Checking to see if command directory: ".
                         $commandDir." exists");

  if (! $self->{FileUtil}->runFileTest("-d",$commandDir)){
    $self->{Logger}->debug("Creating directory command directory: ".
                           $commandDir);

    if (!$self->{FileUtil}->makeDir($commandDir)){
      $self->{Logger}->error("There was a problem making dir: ".
                             $commandDir);
      return undef;
    }
  }
  return $commandDir."/".$job->getJobId().".".
                     $job->getTaskId().
                     $self->{Config}->getCommandsFileSuffix();
}

1;

__END__

=head1 AUTHOR

Panfish::CommandsFileFromJobsCreator is written by Christopher Churas <churas@ncmir.ucsd.edu>

=cut
