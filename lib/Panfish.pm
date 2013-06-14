package Panfish;

use 5.008008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Panfish ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.1';


# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Panfish - A multicluster submission system 

=head1 SYNOPSIS

chum
cast
land
panfish


=head1 DESCRIPTION

Panfish is a set of tools and daemons that let users submit jobs in a similar
process they use for their local cluster, running Oracle/Sun/Open Grid Engine,
with the advantage of those jobs optionally being sent to XSEDE compute
clusters.  Utilizing a Panfish tool (chum) the user first uploads data to XSEDE
compute clusters.  The user then invokes a Panfish command (cast) to submit
their jobs.  This command is a dropin replacement for the one in
Oracle/Sun/Open Grid Engine (qsub.) The user then monitors the jobs via the id
returned by the submission command (cast) as with any normally submitted job.
Upon job completion the user invokes a Panfish command (land) to retrieve the
data.

What happens in the above steps is the Panfish submission command (cast) submits
what is known as a “shadow” job to a set of “shadow” queues that correspond to
the local cluster and other XSEDE compute clusters.  Oracle/Sun/Open Grid Engine
handles the scheduling of these “shadow” jobs to the appropriate “shadow” queue.
Once scheduled and running these “shadow” jobs examine what queue they are under
and let the Panfish daemon  know.  The Panfish daemon on the local compute
cluster then submits those jobs to the corresponding compute resource notifying
the “shadow” job upon completion.  The “shadow” job then exits letting the user
know the work has completed.  The (chum) and (land) commands are wrappers that
simplify the transfer of data to and from remote resources.

Panfish can be run as a cron on the local compute cluster and as a cron job on
each remote XSEDE cluster.  The current implementation runs as a single user and
all jobs are run as that user.  Panfish requires only ssh and rsync and no
configuration adjustment on the remote clusters other than enabling ssh from the
local compute resources to the remote compute resources.


=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Christopher Churas <churas@ncmir.ucsd.edu>

=head1 COPYRIGHT AND LICENSE


=cut
