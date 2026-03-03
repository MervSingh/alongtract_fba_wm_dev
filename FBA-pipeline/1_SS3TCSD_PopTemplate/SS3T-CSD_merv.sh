#!/bin/sh

#########################################################################################################################

# SINGLE SHELL 3-TISSUE CONSTRAINED SPHERICAL DECONVOLUTION #

#########################################################################################################################

# This script utilizes MRtrix3Tissue

cd /bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA

# Set the base directory path
sub_dir='/bulk/bray_bulk/Merv-Along_tract/VSD_AlongTractFBA/subjects'

# Iterate over each subject directory
for subj in "$sub_dir"/*;
do
    # Print a message indicating the current subject being processed
    echo "Processing $subj"
    
    # Perform DWI (Diffusion-Weighted Imaging) SS3TCSD steps
    
    # Estimate response functions using the Dhollander algorithm
    dwi2response dhollander $subj/dwi.bias.1.25mm.mif $subj/response_wm.txt $subj/response_gm.txt $subj/response_csf.txt -force
    
    # Perform single-shell 3-tissue CSD (Constrained Spherical Deconvolution)
    ss3t_csd_beta1 $subj/dwi.bias.1.25mm.mif $subj/response_wm.txt $subj/wmfod.mif $subj/response_gm.txt $subj/gm.mif $subj/response_csf.txt $subj/csf.mif -mask $subj/dwi.bias.1.25mm.mask.mif -force
    
    # Perform  joint bias field and intensity normalization (Merv added on 16.05.2024)
    mtnormalise $subj/wmfod.mif $subj/wmfod_norm.mif $subj/gm.mif $subj/gm_norm.mif $subj/csf.mif $subj/csf_norm.mif -mask $subj/dwi.bias.1.25mm.mask.mif -force
    
    # Calculate the max wmfod normed image (Merv added on 17.05.2024)
    #mrcalc subj/wmfod_norm.mif -max $subj/wmfod_norm_max.mif -force
    
    # Calculate the min wmfod normed image (Merv added on 17.05.2024)
    #mrcalc $subj/wmfod_norm.mif -min $subj/wmfod_norm_min.mif -force
    
    # Generate FOD-based directionally-encoded colour (DEC) map (Merv added on 17.05.2024)
    fod2dec $subj/wmfod_norm.mif $subj/wmdec_norm.mif -mask $subj/dwi.bias.1.25mm.mask.mif -force
    
    # Generate tissue fraction map (Merv added on 17.05.2024)
    #mrconvert –coord 3 0 $subj/wmfod_norm.mif -| mrcat $subj/csf_norm.mif $subj/gm_norm.mif – $subj/tissues_norm.mif -force
done
