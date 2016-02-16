#!/bin/sh
#
#SBATCH -D @PANFISH_JOB_CWD@
#SBATCH -A @PANFISH_ACCOUNT@
#SBATCH -o @PANFISH_JOB_STDOUT_PATH@
#SBATCH -e @PANFISH_JOB_STDERR_PATH@
#SBATCH -J @PANFISH_JOB_NAME@
#SBATCH -p normal
#SBATCH -t @PANFISH_WALLTIME@
#SBATCH -n 1
#SBATCH --export=SLURM_UMASK=0022

/usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@
