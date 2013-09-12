#!/bin/sh
#
# request Bourne shell as shell for job
#$ -S /bin/sh
#$ -V
#$ -wd @PANFISH_JOB_CWD@
#$ -o @PANFISH_JOB_STDOUT_PATH@
#$ -e @PANFISH_JOB_STDERR_PATH@
#$ -N @PANFISH_JOB_NAME@
#$ -q camlow.q
#$ -l h_rt=@PANFISH_WALLTIME@

echo "SGE Id:  ${JOB_ID}.${SGE_TASK_ID}"

/usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@
