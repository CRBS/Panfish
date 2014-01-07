package Panfish::PsubFileFromJobsCreator;



use strict;
use English;
use warnings;

=head1 NAME

Panfish::PsubFileFromJobsCreator -- Creates Psub file given a list of jobs

=head1 SYNOPSIS

  use Panfish::PsubFileFromJobsCreator;
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,
                                $fileutil,$reader,$writer,$logger);

  my ($error) = $psubCreator->create($cluster,\@jobs);
  					   
					   
=head1 DESCRIPTION

Creates Psub file given a list of jobs who already have had a 
commands file created.  
					   
=head1 METHODS


=head3 new

  Creates new Panfish::PsubFileFromJobsCreator

  my $sbatchParser = Panfish::PsubFileFromJobsCreator->new();

=cut

sub new {
  my $class = shift;
  my $self = {
      Config              => shift,
      FileUtil            => shift,
      Reader              => shift,
      Writer              => shift,
      Logger              => shift
  };
  return bless ($self,$class);
}

=head3 create

Creates Psub file given cluster and reference to an array
of Jobs.

my ($error) = $psubCreator->create("foo.q",\@jobs);

=cut

sub create {
  my $self = shift;
  my $cluster = shift; 
  my $jobsArrayRef = shift;

  if (!defined($cluster)){
    return "Cluster not defined";
  }

  if (!defined($jobsArrayRef) || @{$jobsArrayRef}<=0){
    return "No jobs to generate a psub file for";
  }

  my $job;
  my $commandsFile;
  my $psubFile;
  for (my $x = 0; $x < @{$jobsArrayRef}; $x++){
    $job = ${$jobsArrayRef}[$x];

    # for the first job get the commands file and
    # write out the psub file
    # set that psub file path in every job

    if ($x == 0){
      $commandsFile = $job->getCommandsFile();
      
      if (!defined($commandsFile)){
        return "No commands file set for job";
      }
      if (! $self->{FileUtil}->runFileTest("-f",$commandsFile)){
        return "Commands file does not exist";
      }

      $psubFile = $self->_createPsubFile($cluster,$commandsFile,$job);
      if (!defined($psubFile)){
        return "Error creating psub file";
      }
    }
    # set the psub file for each job
    $job->setPsubFile($psubFile);

    # set state of job to batched
    $job->setState(Panfish::JobState->BATCHED());
  }
  return undef;
}


sub _verifyandRetrieveJobAttributes {
  my $self = shift;
  my $cluster = shift;
  my $job = shift;
  my $error = undef;

  my $name = $job->getJobName();
  if (!defined($name)){
    $self->{Logger}->error("Name not defined for job");
    return undef;
  }

  my $curdir = $job->getCurrentWorkingDir();
  if (!defined($curdir)){
    $self->{Logger}->error("Current working directory not set for job");
    return undef;
  }

  my $remoteBaseDir = "";

  # set the path prefix if we are batching for another cluster otherwise dont
  if ($self->{Config}->isClusterPartOfThisCluster($cluster) == 0){
    $remoteBaseDir = $self->{Config}->getBaseDir($cluster);
  }
  
  my $walltime = $job->getWallTime();
  # if not set put 12 hours in for wall time

  if (!defined($walltime)){
    $self->{Logger}->error("Walltime not defined.  Setting to 12:00:00");
    $walltime="12:00:00";
  }

  my $account = $job->getAccount();
  if (!defined($account)){
    $self->{Logger}->error("Account value not defined.  Leaving empty");
    $account = "";
  }
 
  return ($name,$curdir,$walltime,$account,$remoteBaseDir);
}

sub _createPsubFile {
  my $self = shift;
  my $cluster = shift;
  my $commandsFile = shift;
  my $job = shift;

  my ($name,$curdir,$walltime,$account,$remoteBaseDir) = $self->_verifyandRetrieveJobAttributes($cluster,$job);

  if (!defined($name)){
    return undef;
  }

  my $cmdFileSuffix = $self->{Config}->getCommandsFileSuffix();
  my $psubFileSuffix = $self->{Config}->getPsubFileSuffix();

  # take commands File and strip off .commands suffix and replace with .psub
  my $psubFile = $commandsFile;
  $psubFile=~s/$cmdFileSuffix$/$psubFileSuffix/;

  # read in template file and replace tokens and
  # write out as psub file
    my $res = $self->{Reader}->openFile($self->{Config}->getJobTemplateDir()."/".
                              $cluster);
  if (defined($res)){
    $self->{Logger}->error("Unable to open: ".
                           $self->{Config}->getJobTemplateDir().
                           "/".$cluster);
    return undef;
  }

  $self->{Logger}->debug("Creating psub file: $psubFile");
  $res = $self->{Writer}->openFile(">$psubFile");
  if (defined($res)){
    $self->{Logger}->error("There was a problem opening file : ".
                           $psubFile);
    return undef;
  }

  my $runJobScript = $self->{Config}->getPanfishJobRunner($cluster).
                     " --parallel ".
                     $self->{Config}->getJobsPerNode($cluster);

  $self->{Logger}->debug("Current Directory: $curdir");

  my $line = $self->{Reader}->read();
  while(defined($line)){
    chomp($line);
    $line=~s/\@PANFISH_JOB_STDOUT_PATH\@/$remoteBaseDir$psubFile.stdout/g;
    $line=~s/\@PANFISH_JOB_STDERR_PATH\@/$remoteBaseDir$psubFile.stderr/g;
    $line=~s/\@PANFISH_JOB_NAME\@/$name/g;
    $line=~s/\@PANFISH_JOB_CWD\@/$remoteBaseDir$curdir/g;
    $line=~s/\@PANFISH_RUN_JOB_SCRIPT\@/$runJobScript/g;
    $line=~s/\@PANFISH_JOB_FILE\@/$remoteBaseDir$commandsFile/g;
    $line=~s/\@PANFISH_WALLTIME\@/$walltime/g;
    $line=~s/\@PANFISH_ACCOUNT\@/$account/g;

    $self->{Writer}->write($line."\n");

    $line = $self->{Reader}->read();
  }

  $self->{Reader}->close();
  $self->{Writer}->close();

  # give the psub file execute permission for users and groups
  $self->{FileUtil}->makePathUserGroupExecutableAndReadable($psubFile);
  return $psubFile;
}


1;

__END__

=head1 AUTHOR

Panfish::PsubFileFromJobsCreator is written by Christopher Churas <churas@ncmir.ucsd.edu>

=cut
