#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 41;
use Panfish::Job;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# test basic get setter methods
{
  my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid");

  ok(defined($job));

  ok($job->getRealJobId() eq "realjobid");
  $job->setRealJobId("realjobid2");

  ok($job->getPsubFile() eq "psubfile");
  $job->setPsubFile("psubfile2");

  ok($job->getCommandsFile() eq "commandsfile");
  $job->setCommandsFile("commandsfile2");

  ok($job->getModificationTime eq "modificationtime");

  ok($job->getCluster() eq "cluster");

  ok($job->getJobId() eq "jobid");

  ok($job->getTaskId() eq "taskid");

  ok($job->getCurrentWorkingDir() eq "currentworkingdir");

  ok($job->getJobName() eq "jobname");

  ok($job->getCommand() eq "command");

  ok($job->getState() eq "state");
  $job->setState("state2");


  ok($job->getRealJobId() eq "realjobid2");
  ok($job->getPsubFile() eq "psubfile2");
  ok($job->getCommandsFile() eq "commandsfile2");
  ok($job->getState() eq "state2");
                             
}


# test getJobAndTaskId
{
   my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid");
   ok($job->getJobAndTaskId() eq "jobid.taskid");

   $job = Panfish::Job->new("cluster","jobid",undef,"jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid");

   ok($job->getJobAndTaskId() eq "jobid");

   $job = Panfish::Job->new("cluster",undef,undef,"jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid");
   ok(!defined($job->getJobAndTaskId()));

   $job = Panfish::Job->new("cluster",undef,"taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid");
   ok(!defined($job->getJobAndTaskId()));


}

# test equals
{
  my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid");

  ok($job->equals($job) == 1);

  # cluster differs
  my $jobtwo = Panfish::Job->new("cluster2","jobid","taskid","jobname",
                                 "currentworkingdir","command","state",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

  #job id differs
  $jobtwo = Panfish::Job->new("cluster","jobid2","taskid","jobname",
                                 "currentworkingdir","command","state",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

  # task id differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid2","jobname",
                                 "currentworkingdir","command","state",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

  # job name differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid","jobname2",
                                 "currentworkingdir","command","state",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);
  
  # current working dir differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid","jobname",
                                 "currentworkingdir2","command","state",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

  # command differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid","jobname",
                                 "currentworkingdir","command2","state",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

  # state differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid","jobname",
                                 "currentworkingdir","command","state2",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

  # modification time differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid","jobname",
                                 "currentworkingdir","command","state",
                                 "modificationtime2","commandsfile","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 1);
  ok($jobtwo->equals($job) == 1);

  # commandsfile differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid","jobname",
                                 "currentworkingdir","command","state2",
                                 "modificationtime","commandsfile2","psubfile",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

  # psubfile differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid","jobname",
                                 "currentworkingdir","command","state",
                                 "modificationtime","commandsfile","psubfile2",
                                 "realjobid");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

  # state realjobid differs
  $jobtwo = Panfish::Job->new("cluster","jobid","taskid","jobname",
                                 "currentworkingdir","command","state",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid2");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);


  ok($job->equals(undef) == 0);

  $jobtwo = Panfish::Job->new(undef,"jobid","taskid","jobname",
                                 "currentworkingdir","command","state",
                                 "modificationtime","commandsfile","psubfile",
                                 "realjobid2");

  ok($job->equals($jobtwo) == 0);
  ok($jobtwo->equals($job) == 0);

}


