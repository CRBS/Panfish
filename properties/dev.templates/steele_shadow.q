#!/bin/sh
#
#PBS -q tg_workq
#PBS -m n
#PBS -A TG-ASC120040 
#PBS -W umask=0022
#PBS -o @PANFISH_JOB_STDOUT_PATH@
#PBS -e @PANFISH_JOB_STDERR_PATH@
#PBS -V
#PBS -l nodes=1:ppn=8,walltime=12:00:00
#PBS -N @PANFISH_JOB_NAME@
#PBS -d @PANFISH_JOB_CWD@

/usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@
