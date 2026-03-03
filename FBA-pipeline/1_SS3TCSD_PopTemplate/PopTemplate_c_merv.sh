#!/bin/sh

#########################################################################################################################

### POPULATION TEMPLATE (ADDED TO SCRIPT ON 16.05.2024) ###

#########################################################################################################################

# This script utilizes MRtrix3 (v3.0.4)
# Ensure you download the relevent software version (including all dependencies) from: https://www.mrtrix.org/download/

cd /Volumes/My\ Passport/VSD_AlongTractFBA

#########################################################################################################################

### WARPING SUBJECT FODS ANND MASKS TO POPULATION TEMPLATE SPACE (ADDED TO SCRIPT ON 16.05.2024) ###

#########################################################################################################################

# Set the base directory path for the subjects within the template
sub_dir='/Volumes/My\ Passport/VSD_AlongTractFBA/subjects'
template_dir='/Volumes/My\ Passport/VSD_AlongTractFBA/template'

# Iterate over each subject directory
for subj in "$sub_dir"/*;
do
    # Print a message indicating the current subject being processed
    echo "Processing $subj"
    # Register subjects to the template
    mrregister $subj/wmfod_norm.mif -mask1 $subj/dwi.bias.1.25mm.mask.mif $template_dir/wmfod_template.mif -nl_warp $subj/subject2template_warp.mif $subj/template2subject_warp.mif -force
done

# Iterate over each subject directory
for subj in "$sub_dir"/*;
do
    # Print a message indicating the current subject being processed
    echo "Processing $subj"
    # Put all participant dwi masks into template space
    mrtransform $subj/dwi.bias.1.25mm.mask.mif -warp $subj/subject2template_warp.mif -interp nearest -datatype bit $subj/mask_in_template_space.mif -force
done
