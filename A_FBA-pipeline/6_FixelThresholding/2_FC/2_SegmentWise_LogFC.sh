#!/bin/bash

# === Path to input directory (contains all the subfolders) ===
input_base="/PATH/TO/DIRECTORY/template/segmentations/unthresholded_fc_masks_NEW"

# === Path to output directory ===
output_base="/PATH/TO/DIRECTORY/template/segmentations/unthresholded_logfc_masks_NEW"

# === Loop through each subfolder ===
for input_subfolder in "$input_base"/*; do
  if [ -d "$input_subfolder" ]; then
    # Get just the folder name (e.g., AF_left_1)
    folder_name=$(basename "$input_subfolder")

    # Make matching output folder
    output_subfolder="$output_base/$folder_name"
    mkdir -p "$output_subfolder"

    echo "📁 Processing: $folder_name"

    # Loop through each .mif file in the subfolder
    for input_file in "$input_subfolder"/*.mif; do
      [ -e "$input_file" ] || continue

      # Extract just the filename (e.g., FC_subject01.mif)
      file_name=$(basename "$input_file")

      # Define output file path (same name, mirrored structure)
      output_file="$output_subfolder/$file_name"

      echo "  → Log-transforming: $file_name"
      mrcalc "$input_file" -log "$output_file"
    done
  fi
done

echo "✅ Done: All log(FC) .mif files saved with mirrored folder structure."
