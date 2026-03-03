#!/bin/sh

########### Reserve computing resources #########
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=30
#SBATCH --mem=50G
#SBATCH --time=7-00:00:00
#SBATCH --partition=cpu2023
#SBATCH --mail-user=mervynderjeet.singh@ucalgary.ca
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END

####### Set environment variables ###############
module load openmpi/4.1.1-gnu
module load mrtrix3tissue/5.2.9
module load ants/2.3.1
module load fsl/6.0.0-bin

#################################################

# run scripts
bash /bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA/DD_scripts_amended_merv/1d_PopTemplate_merv.sh

#################################################

