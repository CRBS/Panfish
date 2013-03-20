#!/bin/sh
#
# request Bourne shell as shell for job
#$ -S /bin/sh
#$ -V
#$ -cwd
#$ -o @PANFISH_JOB_STDOUT_PATH@
#$ -e @PANFISH_JOB_STDERR_PATH@
#$ -N @PANFISH_JOB_NAME@
#$ -q camlow.q
#$ -l h_rt=12:00:00

/usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@
