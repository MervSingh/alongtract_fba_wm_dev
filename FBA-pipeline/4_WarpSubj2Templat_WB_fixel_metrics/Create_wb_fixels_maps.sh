#!/bin/sh

cd "/Volumes/My Passport/VSD_AlongTractFBA"

# Set the base directory path
sub_dir="/Volumes/My Passport/VSD_AlongTractFBA/VSD_sample/data/FBA_pipeline/subjects"
template_dir="/Volumes/My Passport/VSD_AlongTractFBA/VSD_sample/data/FBA_pipeline/template_tractseg"

#cd $template_dir
# Compute a template voxel mask
#mrconvert $template_dir/wmfod_template.mif -coord 3 0 - | mrthreshold - $template_dir/wmfod_template_voxel_mask.mif -force
#Compute template fixel mask
#fod2fixel -mask $template_dir/wmfod_template_voxel_mask.mif -fmls_peak_value 0.1 $template_dir/wmfod_template.mif $template_dir/fixel_mask -force

cd $sub_dir
# Warp FOD images to template space
for_each * : mrtransform IN/wmfod_norm.mif -warp IN/subject2template_warp.mif -reorient_fod no IN/fod_in_template_space_NOT_REORIENTED.mif
# Segment FOD images to estimate fixels and their apparent fibre density (FD)
for_each * : fod2fixel -mask $template_dir/wmfod_template_voxel_mask.mif IN/fod_in_template_space_NOT_REORIENTED.mif IN/fixel_in_template_space_NOT_REORIENTED -afd fd.mif -force
# Reorient fixels
for_each * : fixelreorient IN/fixel_in_template_space_NOT_REORIENTED IN/subject2template_warp.mif IN/fixel_in_template_space -force
# Assign subject fixels to template fixels
for_each * : fixelcorrespondence IN/fixel_in_template_space/fd.mif $template_dir/fixel_mask $template_dir/fd PRE.mif -force

# Compute fibre cross-section (FC)
for_each * : warp2metric IN/subject2template_warp.mif -fc $template_dir/fixel_mask $template_dir/fc IN.mif -force

# compute log (FC)
mkdir $template_dir/log_fc
cp $template_dir/fc/index.mif $template_dir/fc/directions.mif $template_dir/log_fc -force
for_each * : mrcalc $template_dir/fc/IN.mif -log $template_dir/log_fc/IN.mif -force

# Compute Fibre density/cross-section
mkdir $template_dir/fdc
cp $template_dir/fc/index.mif $template_dir/fdc -force
cp $template_dir/fc/directions.mif $template_dir/fdc -force
for_each * : mrcalc $template_dir/fd/IN.mif $template_dir/fc/IN.mif -mult $template_dir/fdc/IN.mif -force