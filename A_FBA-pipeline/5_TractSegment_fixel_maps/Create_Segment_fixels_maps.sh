#!/bin/sh

# Set paths
template_dir="/PATH/TO/DIRECTORY/template"
tract_dir="$template_dir/segmentations"

segments=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)

# Create FD fixel masks for each ROI segment per tract
cd "$tract_dir" || exit
for tracts in *; do
    cd "$tracts" || continue
    for seg in "${segments[@]}"; do
        echo "creating fixel masks for $tracts segment $seg"
        mkdir -p "$tract_dir/${tracts}/fixel_masks_fd/${tracts}_${seg}"
        tck2fixel ${tracts}_${seg}.tck $template_dir/fd fixel_masks_fd/${tracts}_${seg}/TDI_${tracts}_${seg} ${tracts}_${seg}_TDI.mif -force
        fixelcrop $template_dir/fd fixel_masks_fd/${tracts}_${seg}/TDI_${tracts}_${seg}/${tracts}_${seg}_TDI.mif fixel_masks_fd/${tracts}_${seg}/fd_${tracts}_${seg} -force
    done
    cd ../
done

# Create FC fixel masks for each ROI segment per tract
cd "$tract_dir" || exit
for tracts in *; do
    cd "$tracts" || continue
    for seg in "${segments[@]}"; do
        echo "creating fixel masks for $tracts segment $seg"
        mkdir -p "$tract_dir/${tracts}/fixel_masks_fc/${tracts}_${seg}"
        tck2fixel ${tracts}_${seg}.tck $template_dir/fc fixel_masks_fc/${tracts}_${seg}/TDI_${tracts}_${seg} ${tracts}_${seg}_TDI.mif -force
        fixelcrop $template_dir/fc fixel_masks_fc/${tracts}_${seg}/TDI_${tracts}_${seg}/${tracts}_${seg}_TDI.mif fixel_masks_fc/${tracts}_${seg}/fc_${tracts}_${seg} -force
    done
    cd ../
done