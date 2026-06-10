#!/bin/sh

cd /Users/mervynsingh/Desktop/ALONG_TRACT
# Set paths
template_dir="/Users/mervynsingh/Desktop/ALONG_TRACT/template_tractseg_new"
#tract_dir="$template_dir/segmentations"
tract_dir="$template_dir/segmentations/NEW"

segments=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)


# Write out the distribution of fd for each fixel within each ROI segment per tract for each subject
cd "$tract_dir" || exit
for tract in *; do 
    cd "$tract_dir/$tract" || continue
    folder="fixel_masks_fd"
    cd "$folder" || continue
    for segment in "${segments[@]}"; do
        subfolder="${tract}_${segment}"
        if [ -d "$subfolder" ]; then
            cd "$subfolder" || continue
            for masks in fd_${tract}_${segment}; do
                if [ -d "$masks" ]; then
                    cd "$masks" || continue
                    for subject in 10*; do
                        echo "$tract $folder $subfolder $masks $subject"
                        # Uncomment the following line if you need to run mrstats
                        #mrstats "$subject" > "${subject}_${subfolder}_meanfd.txt" -force
                        mrdump "$subject" > "${subject}_${subfolder}_fd_distribution.txt" -force
                    done
                    cd ..
                fi
            done
            cd ..
        fi
    done
    cd "$tract_dir" || exit
done