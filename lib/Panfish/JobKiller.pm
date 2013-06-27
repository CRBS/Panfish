package Panfish::JobKiller;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::FileJobDatabase;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
  Panfish::JobKiller

=head1 DESCRIPTION

Kills running real job that corresponds to shadow job

=head1 METHODS

=head3 new

Creates new instance of Job object



=cut

sub new {
   my $class = shift;
   my $self = {
     Config     => shift,
     JobDb      => shift,
     Logger     => shift,
     FileUtil   => shift,
     Executor   => shift,
     JobKiller  => shift
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 killJob

Given a cluster and a job this method invokes proper command
to kill the real job on the current cluster.

my $res = $killer->killJob($cluster,$job);

=cut

sub killJob {
    my $self = shift;
    my $cluster = shift;
    my $job = shift;

    

    if (!defined($cluster)){
        $self->{Logger}->error("Cluster is not set");
        return "Cluster is not set";
    }
    return undef;
}

1;

__END__


=head1 AUTHOR

Panfish::JobKiller is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

