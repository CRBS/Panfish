package Panfish::PanfishConfig;

use strict;
use English;
use warnings;

use FindBin qw($Bin);

=head1 SYNOPSIS
   
  Panfish::PanfishConfig -- Represents a Panfish configuration

=head1 DESCRIPTION

 Represents Panfish configuration. 

=head1 METHODS

=head3 new

=cut

sub new {
   my $class = shift;
   my $self = {
     Config           => shift,
     QSUB_PATH        => "qsub.path",
     QUEUE_LIST       => "queue.list",
     LINE_STDERR_PATH => "line.stderr.path",
     LINE_STDOUT_PATH => "line.stdout.path",
     SUBMIT_DIR       => "submit.dir",
     JOB_TEMPLATE_DIR => "job.template.dir",
     LINE_COMMAND     => "line"
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 setConfig

Sets config object

=cut

sub setConfig {
  my $self = shift;
  $self->{Config} = shift;
}


=head3 getQsubPath

Returns path to qsub program

my $val = $foo->getQsubPath();

=cut

sub getQsubPath {
    my $self = shift;

    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($self->{QSUB_PATH});
}


sub getQueueList {
    my $self = shift;

    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($self->{QUEUE_LIST});
}

=head3 getLineCommand

Returns the line program name

=cut

sub getLineCommand {
    my $self = shift; # technically don't need to bother to do this
    return "$Bin/".$self->{LINE_COMMAND};
}

=head3 getLineStandardErrorPath 

Gets the Standard error directory for line command

=cut

sub getLineStandardErrorPath {
    my $self = shift;
    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($self->{LINE_STDERR_PATH});
}


=head3 getLineStandardOutPath 

Gets the Standard out directory for line command

=cut

sub getLineStandardOutPath {
    my $self = shift;
    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($self->{LINE_STDOUT_PATH});
}

1;

__END__

=head1 AUTHOR

   Panfish::PanfishConfig is written by Christopher Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut

