#!/bin/sh
#
# request Bourne shell as shell for job
#$ -S /bin/bash
#$ -V
#$ -p -100
#$ -wd @PANFISH_JOB_CWD@
#$ -o @PANFISH_JOB_STDOUT_PATH@
#$ -e @PANFISH_JOB_STDERR_PATH@
#$ -N @PANFISH_JOB_NAME@
#$ -q himem.q
#$ -l h_rt=@PANFISH_WALLTIME@,h_vmem=15G,virtual_free=10G

echo "SGE Id:  ${JOB_ID}.${SGE_TASK_ID}"

/usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@
