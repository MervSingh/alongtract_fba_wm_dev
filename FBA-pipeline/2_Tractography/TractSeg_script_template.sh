#!/bin/sh

#########################################################################################################################

# SUBJECT-LEVEL TRACTOGRAPHY (TRACTSEG) USING FOD PEAKS WARPED TO TEMPLATE SPACE #

#########################################################################################################################

# Use with Anaconda Prompt
# create a conda virtual environment within the env python subdirectory (you can call it whatever you like but for simplicity, I like to call it 'tractseg')
# install TractSeg + dependencies to the virutal envioronment
# To activate the conda virtual environment, use 'conda activate tractseg'

cd /Users/mervynsingh/Desktop/ALONG_TRACT/template_tractseg_new

# Run TractSeg on peaks in template space
    
# Tract segmentation
# Endings segmentation
# Track Orientation Map (TOM)
# Perform tracking
#sh2peaks wmfod_template.nii.gz wmfod_template_peaks.nii.gz -force 
#TractSeg -i wmfod_template_peaks.nii.gz --output_type tract_segmentation 
#TractSeg -i wmfod_template_peaks.nii.gz --output_type endings_segmentation
#TractSeg -i wmfod_template_peaks.nii.gz --output_type TOM
#Tracking -i wmfod_template_peaks.nii.gz --bundles CST_left,CST_right,SLF_I_left,SLF_I_right,IFO_left,IFO_right --tracking_dilation 1 --tracking_format tck --nr_fibers 10000
#Tracking -i wmfod_template_peaks.nii.gz --bundles CC_4 --tracking_dilation 1 --tracking_format tck --nr_fibers 10000
#Tracking -i wmfod_template_peaks.nii.gz --bundles UF_left,UF_right --tracking_dilation 1 --tracking_format tck --nr_fibers 10000
Tracking -i wmfod_template_peaks.nii.gz --tracking_dilation 1 --tracking_format tck --nr_fibers 10000

