#!/bin/sh

#########################################################################################################################

### POPULATION TEMPLATE (ADDED TO SCRIPT ON 16.05.2024) ###

#########################################################################################################################

# This script utilizes MRtrix3 (v3.0.4)
# Ensure you download the relevent software version (including all dependencies) from: https://www.mrtrix.org/download/

cd /bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA

# Set the base directory path
sub_dir='/bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA/subjects'

# create template directories
mkdir -p template/Template_subjects
mkdir template/fod_input
mkdir template/mask_input

# Get list of subjects directories: note these are subjects chosen for the template stage
mapfile -t template_subjects < /bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA/sub_list/TemplateSubjects.txt

for subj in "${template_subjects[@]}";
do
    # Print a message indicating the current subject being processed
    echo "Processing $subj"
    # link the wmfod and mask images to the template directory
    ln -sr $sub_dir/$subj/wmfod_norm.mif template/fod_input/${subj}.mif
    ln -sr $sub_dir/$subj/dwi.bias.1.25mm.mask.mif template/mask_input/${subj}.mif
done
