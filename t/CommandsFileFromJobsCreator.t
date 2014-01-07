#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 142;

use Mock::Logger;
use Mock::FileUtil;
use Mock::FileReaderWriter;
use Panfish::CommandsFileFromJobsCreator;
use Panfish::Job;
use Panfish::Config;
use Panfish::PanfishConfig;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $bconfig = Panfish::Config->new();
my $config = Panfish::PanfishConfig->new($bconfig);


# Test create with undef cluster
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();
  
  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);

  ok($cmdCreator->create(undef) eq "Cluster not defined");
}

# Test create with undef jobs ref and an empty jobs ref
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();

  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);

  ok($cmdCreator->create("foo",undef) eq "No jobs to generate a Commands file for");

  my @jobs;
  ok($cmdCreator->create("foo",\@jobs) eq "No jobs to generate a Commands file for");
}

# Test create with undef working directory
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();

  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);


  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name",
                               undef, #current working dir
                               "command",
                               undef, # state
                               12345, # modification time
                               undef, #cmds file
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account

  ok($cmdCreator->create("foo",\@jobs) eq "Unable to get Command File");
  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "ERROR Current working directory not defined for job");
}


# Test create where directory does not exist and makedir fails
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();

  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);


  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name",
                               "/cwd", #current working dir
                               "command",
                               undef, # state
                               12345, # modification time
                               undef, #cmds file
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account

  $fileUtil->addRunFileTestResult("-d","/cwd/foo",0);
  $fileUtil->addMakeDirResult("/cwd/foo",0);

  ok($cmdCreator->create("foo",\@jobs) eq "Unable to get Command File");
  my @logs = $logger->getLogs();
  ok(@logs == 3);
  ok($logs[0] eq "DEBUG Checking to see if command directory: /cwd/foo exists");
  ok($logs[1] eq "DEBUG Creating directory command directory: /cwd/foo");
  ok($logs[2] eq "ERROR There was a problem making dir: /cwd/foo");
}

# Test create where directory does not exist make dir succeeds, but open fails
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();

  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);


  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name",
                               "/cwd", #current working dir
                               "command",
                               undef, # state
                               12345, # modification time
                               undef, #cmds file
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account

  $fileUtil->addRunFileTestResult("-d","/cwd/foo",1);
  $writer->addOpenFileResult(">/cwd/foo/1.2".$config->getCommandsFileSuffix(),"uh");
  ok($cmdCreator->create("foo",\@jobs) eq "Unable to open file /cwd/foo/1.2".
                                          $config->getCommandsFileSuffix());

  my @logs = $logger->getLogs();
  ok(@logs == 3);
 
  ok($logs[0] eq "DEBUG Checking to see if command directory: /cwd/foo exists");
  ok($logs[1] eq "DEBUG Creating command file: /cwd/foo/1.2".$config->getCommandsFileSuffix());
  ok($logs[2] eq "ERROR There was a problem opening file: /cwd/foo/1.2".$config->getCommandsFileSuffix());
}


# Test create where job in array is undef
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();

  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);


  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name",
                               "/cwd", #current working dir
                               "command",
                               undef, # state
                               12345, # modification time
                               undef, #cmds file
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account
  $jobs[1] = undef;

  $fileUtil->addRunFileTestResult("-d","/cwd/foo",1);
  $writer->addOpenFileResult(">/cwd/foo/1.2".$config->getCommandsFileSuffix(),undef);
  ok($cmdCreator->create("foo",\@jobs) eq "Undefined job found");

  my @logs = $logger->getLogs();
  ok(@logs == 3);

  ok($logs[0] eq "DEBUG Checking to see if command directory: /cwd/foo exists");
  ok($logs[1] eq "DEBUG Creating command file: /cwd/foo/1.2".$config->getCommandsFileSuffix());
  ok($logs[2] eq "ERROR Job # 1 pulled from array is not defined. wtf");
}
 

# Test create where we have one job
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();

  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);


  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name",
                               "/cwd", #current working dir
                               "command",
                               undef, # state
                               12345, # modification time
                               undef, #cmds file
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account

  $fileUtil->addRunFileTestResult("-d","/cwd/foo",1);
  $writer->addOpenFileResult(">/cwd/foo/1.2".$config->getCommandsFileSuffix(),undef);
  ok(!defined($cmdCreator->create("foo",\@jobs)));

  ok($jobs[0]->getCommandsFile() eq "/cwd/foo/1.2".$config->getCommandsFileSuffix());
  
  my @writes = $writer->getWrites();
  ok(@writes == 1);
  ok($writes[0] eq "command\n");

  my @logs = $logger->getLogs();
  ok(@logs == 2);

  ok($logs[0] eq "DEBUG Checking to see if command directory: /cwd/foo exists");
  ok($logs[1] eq "DEBUG Creating command file: /cwd/foo/1.2".$config->getCommandsFileSuffix());
}

# Test create where we have two jobs
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();

  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);


  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name",
                               "/cwd", #current working dir
                               "command",
                               undef, # state
                               12345, # modification time
                               undef, #cmds file
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account
  $jobs[1] = Panfish::Job->new("foo","1","3","name",
                               "/cwd", #current working dir
                               "command2",
                               undef, # state
                               12345, # modification time
                               undef, #cmds file
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account

  
 
  $fileUtil->addRunFileTestResult("-d","/cwd/foo",1);
  $writer->addOpenFileResult(">/cwd/foo/1.2".$config->getCommandsFileSuffix(),undef);
  ok(!defined($cmdCreator->create("foo",\@jobs)));

  ok($jobs[0]->getCommandsFile() eq "/cwd/foo/1.2".$config->getCommandsFileSuffix());
  ok($jobs[1]->getCommandsFile() eq "/cwd/foo/1.2".$config->getCommandsFileSuffix());

  my @writes = $writer->getWrites();
  ok(@writes == 2);
  ok($writes[0] eq "command\n");
  ok($writes[1] eq "command2\n");

  my @logs = $logger->getLogs();
  ok(@logs == 2);

  ok($logs[0] eq "DEBUG Checking to see if command directory: /cwd/foo exists");
  ok($logs[1] eq "DEBUG Creating command file: /cwd/foo/1.2".$config->getCommandsFileSuffix());
}

# Test where we have 50 jobs
{
  my $logger = Mock::Logger->new();
  my $fileUtil = Mock::FileUtil->new();
  my $writer = Mock::FileReaderWriter->new();

  my $cmdCreator = Panfish::CommandsFileFromJobsCreator->new($config,$fileUtil,
                                                              $writer,
                                                              $logger);


  my @jobs;
  for (my $x = 0; $x < 50 ; $x++){
    $jobs[$x] = Panfish::Job->new("foo","1",$x+2,"name",
                               "/cwd", #current working dir
                               "command".$x,
                               undef, # state
                               12345, # modification time
                               undef, #cmds file
                               undef,  # psubfile
                               undef,  # real job id
                               undef,  # fail reason
                               undef,  # batchfactor
                               undef,  # walltime
                               undef); # account

  }

  $fileUtil->addRunFileTestResult("-d","/cwd/foo",1);
  $writer->addOpenFileResult(">/cwd/foo/1.2".$config->getCommandsFileSuffix(),undef);
  ok(!defined($cmdCreator->create("foo",\@jobs)));

  my @writes = $writer->getWrites();
  ok(@writes == 50);
  for (my $x = 0; $x < 50; $x++){
    ok($jobs[$x]->getCommandsFile() eq "/cwd/foo/1.2".
                                       $config->getCommandsFileSuffix());
    ok($writes[$x] eq "command".$x."\n");
  }

  my @logs = $logger->getLogs();
  ok(@logs == 2);

  ok($logs[0] eq "DEBUG Checking to see if command directory: /cwd/foo exists");
  ok($logs[1] eq "DEBUG Creating command file: /cwd/foo/1.2".$config->getCommandsFileSuffix());
}

