#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 67;

use Mock::Logger;
use Mock::FileUtil;
use Mock::FileReaderWriter;

use Panfish::PsubFileFromJobsCreator;
use Panfish::PanfishConfig;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $timeout = 60; #default timeout

my $baseConfig = Panfish::Config->new();
$baseConfig->setParameter("this.cluster","foo");
$baseConfig->setParameter("foo.jobs.per.node","1");
$baseConfig->setParameter("foo.panfishjobrunner","runner");
$baseConfig->setParameter("foo.job.template.dir","/template");
$baseConfig->setParameter("cluster.list","foo");
$baseConfig->setParameter("foo.basedir","/base");

# Test create with undef cluster
{
  my $logger = Mock::Logger->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);

  ok($psubCreator->create(undef) eq "Cluster not defined");
}

# Test create with undef jobs and empty jobs array
{
  my $logger = Mock::Logger->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);

  ok($psubCreator->create("foo",undef) eq "No jobs to generate a psub file for");
  my @jobs;
  ok($psubCreator->create("foo",\@jobs) eq "No jobs to generate a psub file for");
}

# Test create with first job commands file undef and in another side
# test when commands file is set but does not exist
{
  my $logger = Mock::Logger->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);
  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1");
  ok($psubCreator->create("foo",\@jobs) eq "No commands file set for job");
  
}

# Test create where there isnt a template file
{
  my $logger = Mock::Logger->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);
  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                               Panfish::JobState->SUBMITTED(),12345,
                               "/cwd/cmds".$config->getCommandsFileSuffix(),
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account
 
  
  $fileUtil->addRunFileTestResult("-f","/cwd/cmds".$config->getCommandsFileSuffix(),
                                  1);
  
  $reader->addOpenFileResult($config->getJobTemplateDir()."/foo","Unable to open");
  my $res = $psubCreator->create("foo",\@jobs);
  ok($res eq "Error creating psub file");

  my @logs = $logger->getLogs();
  ok(@logs == 3);
  ok($logs[0] eq "ERROR Walltime not defined.  Setting to 12:00:00");
  ok($logs[1] eq "ERROR Account value not defined.  Leaving empty");
  ok($logs[2] eq "ERROR Unable to open: /template/foo");
}

# Test create where there is an error creating psub file
{
  my $logger = Mock::Logger->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);
  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                               Panfish::JobState->SUBMITTED(),12345,
                               "/cwd/cmds".$config->getCommandsFileSuffix(),
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account


  $fileUtil->addRunFileTestResult("-f","/cwd/cmds".$config->getCommandsFileSuffix(),
                                  1);
  
  $reader->addOpenFileResult($config->getJobTemplateDir()."/foo",undef);
  $writer->addOpenFileResult(">/cwd/cmds".$config->getPsubFileSuffix(),"doh");
  my $res = $psubCreator->create("foo",\@jobs);
  ok($res eq "Error creating psub file");

  my @logs = $logger->getLogs();
  ok(@logs == 4);
  ok($logs[0] eq "ERROR Walltime not defined.  Setting to 12:00:00");
  ok($logs[1] eq "ERROR Account value not defined.  Leaving empty");

  ok($logs[2] eq "DEBUG Creating psub file: /cwd/cmds".$config->getPsubFileSuffix());
  ok($logs[3] eq "ERROR There was a problem opening file : /cwd/cmds".$config->getPsubFileSuffix());
}

# Test create where name is undef
{
  my $logger = Mock::Logger->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);
  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2",undef,"/cwd","command",
                               Panfish::JobState->SUBMITTED(),12345,
                               "/cwd/cmds".$config->getCommandsFileSuffix(),
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account

  $fileUtil->addRunFileTestResult("-f","/cwd/cmds".$config->getCommandsFileSuffix(),
                                  1);

  my $res = $psubCreator->create("foo",\@jobs);
  ok($res eq "Error creating psub file");

  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "ERROR Name not defined for job");
}

# Test create for Current Working Dir is undef
{
  my $logger = Mock::Logger->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);
  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name",undef,"command",
                               Panfish::JobState->SUBMITTED(),12345,
                               "/cwd/cmds".$config->getCommandsFileSuffix(),
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account

  $fileUtil->addRunFileTestResult("-f","/cwd/cmds".$config->getCommandsFileSuffix(),
                                  1);

  my $res = $psubCreator->create("foo",\@jobs);
  ok($res eq "Error creating psub file");

  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "ERROR Current working directory not set for job");
}


# Test create where batch is for local cluster, walltime, and account
# are not defined
{
  my $logger = Mock::Logger->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);
  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                               Panfish::JobState->SUBMITTED(),12345,
                               "/cwd/cmds".$config->getCommandsFileSuffix(),
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account


  $fileUtil->addRunFileTestResult("-f","/cwd/cmds".$config->getCommandsFileSuffix(),
                                  1);

  $reader->addOpenFileResult($config->getJobTemplateDir()."/foo",undef);

  $reader->addReadResult("/usr/bin/time -p \@PANFISH_RUN_JOB_SCRIPT@ \@PANFISH_JOB_FILE@");
  $reader->addReadResult("");
  $reader->addReadResult("");
  $reader->addReadResult("#SBATCH -n 16");
  $reader->addReadResult("#SBATCH -t \@PANFISH_WALLTIME@");
  $reader->addReadResult("#SBATCH -p development");
  $reader->addReadResult("#SBATCH -J \@PANFISH_JOB_NAME@");
  $reader->addReadResult("#SBATCH -e \@PANFISH_JOB_STDERR_PATH@");
  $reader->addReadResult("#SBATCH -o \@PANFISH_JOB_STDOUT_PATH@");
  $reader->addReadResult("#SBATCH -A \@PANFISH_ACCOUNT@");
  $reader->addReadResult("#SBATCH -D \@PANFISH_JOB_CWD@");
  $reader->addReadResult("#");
  $reader->addReadResult("#!/bin/sh");

  $writer->addOpenFileResult(">/cwd/cmds".$config->getPsubFileSuffix(),undef);

  my $res = $psubCreator->create("foo",\@jobs);
  ok(!defined($res));

  my @writes = $writer->getWrites();
  ok(@writes == 13);
  ok($writes[0] eq "#!/bin/sh\n");
  ok($writes[1] eq "#\n");
  ok($writes[2] eq "#SBATCH -D /cwd\n");
  ok($writes[3] eq "#SBATCH -A \n");
  ok($writes[4] eq "#SBATCH -o /cwd/cmds.psub.stdout\n");
  ok($writes[5] eq "#SBATCH -e /cwd/cmds.psub.stderr\n");
  ok($writes[6] eq "#SBATCH -J name\n");
  ok($writes[7] eq "#SBATCH -p development\n");
  ok($writes[8] eq "#SBATCH -t 12:00:00\n");
  ok($writes[9] eq "#SBATCH -n 16\n");
  ok($writes[10] eq "\n");
  ok($writes[11] eq "\n");
  ok($writes[12] eq "/usr/bin/time -p /panfishjobrunner --parallel 1 /cwd/cmds.commands\n");


  # check job state and psub file
  ok($jobs[0]->getState() eq Panfish::JobState->BATCHED());
  ok($jobs[0]->getPsubFile() eq "/cwd/cmds.psub");


  my @logs = $logger->getLogs();
  ok(@logs == 4);
  ok($logs[0] eq "ERROR Walltime not defined.  Setting to 12:00:00");
  ok($logs[1] eq "ERROR Account value not defined.  Leaving empty");

  ok($logs[2] eq "DEBUG Creating psub file: /cwd/cmds".
                  $config->getPsubFileSuffix());
  ok($logs[3] eq "DEBUG Current Directory: /cwd");
  
}  

# Test where its all good and job is remote
{
  my $logger = Mock::Logger->new();

  my $bConfig = Panfish::Config->new();
  $bConfig->setParameter("this.cluster","foo");
  $bConfig->setParameter("foo.jobs.per.node","1");
  $bConfig->setParameter("foo.panfishjobrunner","runner");
  $bConfig->setParameter("foo.job.template.dir","/template");
  $bConfig->setParameter("cluster.list","foo,bar");
  $bConfig->setParameter("foo.basedir","/base");
  $bConfig->setParameter("bar.jobs.per.node","2");
  $bConfig->setParameter("bar.panfishjobrunner","runner");
  $bConfig->setParameter("bar.job.template.dir","/template");
  $bConfig->setParameter("bar.basedir","/bardir");
  $bConfig->setParameter("bar.host","ha");

  my $config = Panfish::PanfishConfig->new($bConfig);

  my $fileUtil = Mock::FileUtil->new();
  my $reader = Mock::FileReaderWriter->new();
  my $writer = Mock::FileReaderWriter->new();
  my $psubCreator = Panfish::PsubFileFromJobsCreator->new($config,$fileUtil,
                                                          $reader,$writer,
                                                          $logger);
  my @jobs;
  $jobs[0] = Panfish::Job->new("bar","1","2","name","/cwd","command",
                               Panfish::JobState->SUBMITTED(),12345,
                               "/cwd/cmds".$config->getCommandsFileSuffix(),
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account
  $jobs[1] = Panfish::Job->new("bar","1","3","name","/cwd","command",
                               Panfish::JobState->SUBMITTED(),12345,
                               "/cwd/cmds".$config->getCommandsFileSuffix(),
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account


  $fileUtil->addRunFileTestResult("-f","/cwd/cmds".$config->getCommandsFileSuffix(),
                                  1);

  $reader->addOpenFileResult($config->getJobTemplateDir()."/foo",undef);

  $reader->addReadResult("/usr/bin/time -p \@PANFISH_RUN_JOB_SCRIPT@ \@PANFISH_JOB_FILE@");
  $reader->addReadResult("");
  $reader->addReadResult("");
  $reader->addReadResult("#SBATCH -n 16");
  $reader->addReadResult("#SBATCH -t \@PANFISH_WALLTIME@");
  $reader->addReadResult("#SBATCH -p development");
  $reader->addReadResult("#SBATCH -J \@PANFISH_JOB_NAME@");
  $reader->addReadResult("#SBATCH -e \@PANFISH_JOB_STDERR_PATH@");
  $reader->addReadResult("#SBATCH -o \@PANFISH_JOB_STDOUT_PATH@");
  $reader->addReadResult("#SBATCH -A \@PANFISH_ACCOUNT@");
  $reader->addReadResult("#SBATCH -D \@PANFISH_JOB_CWD@");
  $reader->addReadResult("#");
  $reader->addReadResult("#!/bin/sh");

  $writer->addOpenFileResult(">/cwd/cmds".$config->getPsubFileSuffix(),undef);

  my $res = $psubCreator->create("bar",\@jobs);
  ok(!defined($res));

  my @writes = $writer->getWrites();
  ok(@writes == 13);
  ok($writes[0] eq "#!/bin/sh\n");
  ok($writes[1] eq "#\n");
  ok($writes[2] eq "#SBATCH -D /bardir/cwd\n");
  ok($writes[3] eq "#SBATCH -A \n");
  ok($writes[4] eq "#SBATCH -o /bardir/cwd/cmds.psub.stdout\n");
  ok($writes[5] eq "#SBATCH -e /bardir/cwd/cmds.psub.stderr\n");
  ok($writes[6] eq "#SBATCH -J name\n");
  ok($writes[7] eq "#SBATCH -p development\n");
  ok($writes[8] eq "#SBATCH -t 12:00:00\n");
  ok($writes[9] eq "#SBATCH -n 16\n");
  ok($writes[10] eq "\n");
  ok($writes[11] eq "\n");
  ok($writes[12] eq "/usr/bin/time -p /panfishjobrunner --parallel 2 /bardir/cwd/cmds.commands\n");

  # check job state and psub file
  ok($jobs[0]->getState() eq Panfish::JobState->BATCHED());
  ok($jobs[0]->getPsubFile() eq "/cwd/cmds.psub");

  ok($jobs[1]->getState() eq Panfish::JobState->BATCHED());
  ok($jobs[1]->getPsubFile() eq "/cwd/cmds.psub");



  my @logs = $logger->getLogs();
  ok(@logs == 4);
  ok($logs[0] eq "ERROR Walltime not defined.  Setting to 12:00:00");
  ok($logs[1] eq "ERROR Account value not defined.  Leaving empty");

  ok($logs[2] eq "DEBUG Creating psub file: /cwd/cmds".
                  $config->getPsubFileSuffix());
  ok($logs[3] eq "DEBUG Current Directory: /cwd");
}

