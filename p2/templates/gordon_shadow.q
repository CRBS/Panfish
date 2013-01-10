#!/bin/sh
#
#PBS -q normal
#PBS -m n
#PBS -A ddp140
#PBS -W umask=0022
#PBS -o @PANFISH_JOB_STDOUT_PATH@
#PBS -e @PANFISH_JOB_STDERR_PATH@
#PBS -V
#PBS -l nodes=1:ppn=16,walltime=00:10:00
#PBS -N @PANFISH_JOB_ID@
#PBS -d @PANFISH_JOB_CWD@
