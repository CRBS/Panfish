package Panfish::SubmitCommand;



use strict;
use English;
use warnings;

=head1 NAME

Panfish::SubmitCommand -- Runs command to submit a job

=head1 SYNOPSIS

  use Panfish::SubmitCommand;
  my $executor = Panfish::ForkExecutor->new();
  my $logger = Panfish::Logger->new();
  my $qsubParser = Panfish::SGEQsubParser->new();
  my $sub = Panfish::SubmitCommand->new($logger,$exec,$qsubParser,"/usr/bin/qsub",60,2,20);

  my ($jobId,$error) = $sub->run($args);
  					   
					   
=head1 DESCRIPTION

Instances of this class submit a job using command line program.

					   
=head1 METHODS


=head3 new

  Creates new Panfish::SubmitCommand

  my $executor = Panfish::ForkExecutor->new();
  my $logger = Panfish::Logger->new();
  my $qsubParser = Panfish::SGEQsubParser->new();
  my $sub = Panfish::SubmitCommand->new($logger,$exec,"/usr/bin/qsub",$qsubParser,60,2,20);

=cut

sub new {
    my $class = shift;
    my $self = {
        Logger        => shift,
        Executor      => shift,
        Command       => shift,
        CommandParser => shift,
        TimeOut       => shift,
        MaxRetries    => shift,
        RetryTimeOut  => shift,
	};
    return bless ($self,$class);
}

=head3 run

Invokes qsub passing arguments passed into method

my ($jobId,$error) = $qsub->run("/blah/foo.qsub");

=cut

sub run {
    my $self = shift;
    my $args = shift;

    if (!defined($args)){
       $self->{Logger}->error($self->{Command}." requires arguments");
       return (undef,$self->{Command}." equires arguments");
    }

    my $cmd = $self->{Command}." ".$args;

    $exit = $self->{Executor}->executeCommandWithRetry($self->{MaxRetries},$self->{RetryTimeOut},$cmd,$self->{TimeOut});
    if ($exit != 0){
         $self->{Logger}->error("Unable to run ".$self->{Executor}->getCommand().
                               "  : ".$self->{Executor}->getOutput());
         return (undef,"Unable to run ".$self->{Executor}->getCommand().
                               "  : ".$self->{Executor}->getOutput());
    }

    return $self->{CommandParser}->parse($self->{Executor}->getOutput());
}

1;

__END__

=head1 AUTHOR

Panfish::SubmitCommand is written by Christopher Churas <churas@ncmir.ucsd.edu>

=cut
