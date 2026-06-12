#!/bin/bash

# Define paths
original_csv="/PATH/TO/INPUT/highest_second_bin_values_fd_tracts.csv"
csv_path_cleaned="/tmp/cleaned_thresholds.csv"
input_base_dir="/PATH/TO/DIRECTORY/template/segmentations/unthresholded_fd_masks_NEW"
output_base_dir="/PATH/TO/DIRECTORY/template/segmentations/thresholded_fd_masks_NEW"
summary_csv="$output_base_dir/summary_fd_values.csv"
log_file="$output_base_dir/processing_log.txt"

# Create output directory
mkdir -p "$output_base_dir"

# Clean the CSV by removing carriage returns
tr -d '\r' < "$original_csv" > "$csv_path_cleaned"
csv_path="$csv_path_cleaned"

# Read thresholds into associative array
declare -A thresholds
{
    read  # Skip header
    while IFS=',' read -r folder value; do
        folder_cleaned=$(echo "$folder" | xargs)  # remove leading/trailing spaces
        value_cleaned=$(echo "$value" | xargs)
        thresholds["$folder_cleaned"]="$value_cleaned"
    done
} < "$csv_path"

# 🔍 Debug: Print all loaded thresholds
echo "✅ Loaded thresholds:"
for key in "${!thresholds[@]}"; do
    echo " - '$key' → ${thresholds[$key]}"
done

# Prepare output CSV header
echo "Tract,Subject,MeanFD,TotalFixels,RemovedFixels,RetainedFixels" > "$summary_csv"
> "$log_file"  # clear log

# Loop through each tract
for tract in "${!thresholds[@]}"; do
    threshold="${thresholds[$tract]}"
    threshold_clean=$(printf "%.4f" "$threshold")

    # 🔍 Debug: Report current tract
    echo "🔍 Processing tract: '$tract' (Threshold: $threshold_clean)"

    tract_dir="$input_base_dir/$tract"
    output_tract_dir="$output_base_dir/$tract"
    mkdir -p "$output_tract_dir"

    if [[ ! -d "$tract_dir" ]]; then
        echo "❌ Missing input folder for $tract — skipping" | tee -a "$log_file"
        continue
    fi

    for file in "$tract_dir"/108*.mif; do
        [[ -e "$file" ]] || continue  # skip if no .mif files

        filename=$(basename "$file")
        subject="${filename%%.*}"

        mrdump_file="$output_tract_dir/${subject}_dump_thresh-${threshold_clean}.txt"
        mrthreshold_file="$output_tract_dir/${subject}_thresholded_thresh-${threshold_clean}.mif"
        threshold_mask="$output_tract_dir/${subject}_mask_from_thresh_thresh-${threshold_clean}.mif"
        mrthreshold_masked_file="$output_tract_dir/${subject}_thresholded_masked_thresh-${threshold_clean}.mif"

        # Run mrdump and count fixels on original file to get total fixels count
        original_mrdump_file="$output_tract_dir/${subject}_original_dump.txt"
        mrdump "$file" > "$original_mrdump_file"
        original_total_fixels=$(wc -l < "$original_mrdump_file")

        # Apply thresholding using mrcalc (retain values >= threshold)
        mrcalc "$file" "$threshold" -ge "$file" -mult "$mrthreshold_file"

        # Create binary mask from thresholded FD file (1 where > 0, else 0)
        mrcalc "$mrthreshold_file" 0 -gt "$threshold_mask"

        # Apply the binary mask to thresholded FD file to keep only non-zero fixels
        mrcalc "$mrthreshold_file" "$threshold_mask" -mult "$mrthreshold_masked_file"

        # Run mrdump on masked file using mask so only non-zero fixels are dumped
        mrdump -mask "$threshold_mask" "$mrthreshold_masked_file" > "$mrdump_file"

        # Count retained fixels and calculate stats from dump file
        retained_fixels=$(wc -l < "$mrdump_file")
        removed_fixels=$((original_total_fixels - retained_fixels))
        mean_fd=$(awk '{sum+=$1} END {if (NR>0) print sum/NR; else print 0}' "$mrdump_file")

        # Write summary line to CSV
        echo "$tract,$subject,$mean_fd,$original_total_fixels,$removed_fixels,$retained_fixels" >> "$summary_csv"

        echo "✅ Processed $subject in $tract — Retained $retained_fixels / $original_total_fixels fixels"
    done
done

echo "✅ Done. Summary written to:"
echo "$summary_csv"
echo "📄 Log file:"
echo "$log_file"
