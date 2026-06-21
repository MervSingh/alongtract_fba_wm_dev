#!/bin/sh

#########################################################################################################################

# SUBJECT-LEVEL TRACTOGRAPHY (TRACTSEG) USING FOD PEAKS WARPED TO TEMPLATE SPACE #

#########################################################################################################################

# Use with Anaconda Prompt
# create a conda virtual environment within the env python subdirectory (you can call it whatever you like but for simplicity, I like to call it 'tractseg')
# install TractSeg + dependencies to the virutal envioronment
# To activate the conda virtual environment, use 'conda activate tractseg'

cd /PATH/TO/DIRECTORY/template

# Run TractSeg on peaks in template space
    
# Tract segmentation
# Endings segmentation
# Track Orientation Map (TOM)
# Perform tracking
sh2peaks wmfod_template.nii.gz wmfod_template_peaks.nii.gz -force 
TractSeg -i wmfod_template_peaks.nii.gz --output_type tract_segmentation 
TractSeg -i wmfod_template_peaks.nii.gz --output_type endings_segmentation
TractSeg -i wmfod_template_peaks.nii.gz --output_type TOM
Tracking -i wmfod_template_peaks.nii.gz --tracking_dilation 1 --tracking_format tck --nr_fibers 10000

# Copy all .tck files from "tractseg_output/TOM_trackings" to a separate subdirectory called "segmentations" - must be created within the template directory
# Within the "segmentations" subdirectory, create separate subfolders for each tract and copy the corresponding .tck files into these subfolders
