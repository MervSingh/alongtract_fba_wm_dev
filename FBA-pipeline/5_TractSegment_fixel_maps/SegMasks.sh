#!/bin/bash

# ================================
# Settings
# ================================
base_dir="/Users/mervynsingh/Desktop/ALONG_TRACT"
template_dir="$base_dir/template_tractseg_new"
output_dir="$template_dir/tract_masks/segments"

mkdir -p "$output_dir"

# ================================
# Loop through all tract folders
# ================================
seg_dir="$template_dir/segmentations/NEW"

for tract_folder in "$seg_dir"/*/; do
    tract_name=$(basename "$tract_folder")

    # Collect all *_17seg.tck files in this folder
    tck_files=()
    while IFS= read -r -d '' f; do
        tck_files+=("$f")
    done < <(find "$tract_folder" -maxdepth 1 -type f -name "*_17seg.tck" -print0)

    if [ ${#tck_files[@]} -eq 0 ]; then
        echo "⏭️  Skipping tract: $tract_name (no *_17seg.tck files)"
        continue
    fi

    echo "Processing tract: $tract_name"

    for tck_file in "${tck_files[@]}"; do
        base_name=$(basename "$tck_file" .tck)
        output_name="${base_name}_mask.nii.gz"

        echo "  -> $output_name"

        # Generate track density map
        tckmap "$tck_file" "$output_name" -template "$template_dir/wmfod_template.mif" -force

        # Binarize
        mrcalc "$output_name" 0 -gt "$output_name" -force

        # Move to central folder
        mv "$output_name" "$output_dir/"
    done
done

echo "✅ All masks saved in: $output_dir"
