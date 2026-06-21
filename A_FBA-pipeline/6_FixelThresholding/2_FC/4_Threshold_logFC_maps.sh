#!/bin/bash

# === Path Configurations ===
fc_base="/PATH/TO/DIRECTORY/template/segmentations/unthresholded_logfc_masks"
mask_base="/PATH/TO/DIRECTORY/template/segmentations/thresholded_fd_masks"
fc_output="/PATH/TO/DIRECTORY/template/segmentations/thresholded_logfc_masks"
summary_csv="$fc_output/summary_fc_values.csv"
log_file="$fc_output/fc_masking_log.txt"

# Create output root
mkdir -p "$fc_output"
> "$summary_csv"
> "$log_file"

# Write CSV header
echo "Tract,Subject,MeanFC,FC_RetainedFixels" >> "$summary_csv"

# === Loop through FC tracts ===
for tract in "$fc_base"/*; do
    tract_name=$(basename "$tract")
    echo "🔍 Processing FC tract: $tract_name"

    fc_tract_dir="$fc_base/$tract_name"
    mask_tract_dir="$mask_base/$tract_name"
    output_tract_dir="$fc_output/$tract_name"
    mkdir -p "$output_tract_dir"

    if [[ ! -d "$mask_tract_dir" ]]; then
        echo "⚠️  No mask directory for $tract_name — skipping" | tee -a "$log_file"
        continue
    fi

    for fc_file in "$fc_tract_dir"/108*.mif; do
        [[ -e "$fc_file" ]] || continue

        fc_filename=$(basename "$fc_file")
        subject="${fc_filename%%.*}"

        # Find the corresponding FD mask
        mask_file=$(find "$mask_tract_dir" -type f -name "${subject}_mask_from_thresh_thresh-*.mif" | head -n 1)

        if [[ -z "$mask_file" ]]; then
            echo "❌ No matching mask for $subject in $tract_name — skipping" | tee -a "$log_file"
            continue
        fi

        output_file="$output_tract_dir/${subject}_fc_masked.mif"
        dump_file="$output_tract_dir/${subject}_fc_masked.txt"

        # Apply mask to FC map and save new .mif in output directory
        mrcalc "$fc_file" "$mask_file" -mult "$output_file"

        # Dump only retained fixels using mask
        mrdump -mask "$mask_file" "$output_file" > "$dump_file"

        # Extract stats from masked fixels
        retained_fixels=$(wc -l < "$dump_file")
        mean_fc=$(awk '{sum += $1} END {if (NR>0) print sum/NR; else print 0}' "$dump_file")

        # Save stats to CSV
        echo "$tract_name,$subject,$mean_fc,$retained_fixels" >> "$summary_csv"

        echo "✅ Masked FC for $subject ($tract_name) — Retained $retained_fixels fixels" | tee -a "$log_file"
    done
done

echo ""
echo "🏁 All FC masking complete!"
echo "📄 Summary CSV: $summary_csv"
echo "🪵 Log file: $log_file"
