#!/bin/sh

#########################################################################################################################

### POPULATION TEMPLATE (ADDED TO SCRIPT ON 16.05.2024) ###

#########################################################################################################################

# This script utilizes MRtrix3 (v3.0.4)
# Ensure you download the relevent software version (including all dependencies) from: https://www.mrtrix.org/download/

cd /bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA

# Set the base directory path
sub_dir='/bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA/subjects'
template_dir='/bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA/template'

# Get list of subjects directories: note these are subjects chosen for the template stage
mapfile -t template_subjects < /bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA/sub_list/TemplateSubjects.txt

for subj in "${template_subjects[@]}";
do
    # Print a message indicating the current subject being processed
    echo "Processing $subj"
    # copy the 40 subject folders into the template directory
    cp -r $sub_dir/$subj template/Template_subjects/$subj
done


# Get average template mask
# this should also tell you how many images were included in generating the average
mrmath $template_dir/Template_subjects/*/mask_in_template_space.mif min template/template_mask.mif \
        -datatype bit \
        -force