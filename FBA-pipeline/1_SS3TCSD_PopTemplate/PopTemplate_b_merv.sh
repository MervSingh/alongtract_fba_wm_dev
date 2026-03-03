#!/bin/sh

#########################################################################################################################

### POPULATION TEMPLATE (ADDED TO SCRIPT ON 16.05.2024) ###

#########################################################################################################################

# This script utilizes MRtrix3 (v3.0.4)
# Ensure you download the relevent software version (including all dependencies) from: https://www.mrtrix.org/download/

cd /bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA

# Set the base directory path
sub_dir='/bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA/subjects'

cd $sub_dir
# Generate population template
echo "Creating population template"
population_template ../template/fod_input -mask_dir ../template/mask_input ../template/wmfod_template.mif -voxel_size 1.25 -force
