import os
import numpy as np
import pandas as pd
import openpyxl

# Set root directory and demographics path
base_dir = "/Users/mervynsingh/Desktop/ALONG_TRACT/template_tractseg_new/segmentations/NEW"
demographics_excel_path = "/Users/mervynsingh/Desktop/ALONG_TRACT/template_tractseg_new/demographics.xlsx"

# Define list of tracts and hemispheres
tracts = [
    "AF", "FPT", "SCP", "ST_POSTC", "T_POSTC", "ATR", "FX", "SLF_II", "ST_PREC", "T_PREC",
    "CG", "ICP", "ILF", "MLF", "OR", "POPT", "SLF_III", "ST_FO", "ST_OCC", "ST_PAR", "ST_PREF", "ST_PREM", "STR",
    "T_OCC", "T_PAR", "T_PREF", "T_PREM"
]

hemis = ["left", "right"]

# Load demographics
if not os.path.isfile(demographics_excel_path):
    raise FileNotFoundError(f"Demographics file not found: {demographics_excel_path}")
demographics_df = pd.read_excel(demographics_excel_path)

# Store statistics across all tracts
all_statistics = []

# Loop over all tracts and hemispheres
for tract in tracts:
    for hemi in hemis:
        tract_hemi = f"{tract}_{hemi}"
        root_dir = os.path.join(base_dir, tract_hemi, "fixel_masks_fd")

        if not os.path.isdir(root_dir):
            print(f"⚠️ Skipping missing tract directory: {root_dir}")
            continue

        for folder_name in sorted(os.listdir(root_dir)):
            if not folder_name.startswith(tract_hemi + "_"):
                continue

            folder_path = os.path.join(root_dir, folder_name)

            if not os.path.isdir(folder_path):
                continue

            # Find all fixel subfolders
            fixel_folders = sorted([f for f in os.listdir(folder_path) if f.startswith(f"fd_{tract_hemi}_")])

            folder_statistics = []

            for fixel_sub in fixel_folders:
                fixel_path = os.path.join(folder_path, fixel_sub)
                if not os.path.isdir(fixel_path):
                    continue

                txt_files = sorted([f for f in os.listdir(fixel_path) if f.endswith(".txt")])

                for txt_file in txt_files:
                    subject_id = txt_file.split(".")[0]
                    file_path = os.path.join(fixel_path, txt_file)

                    try:
                        data = np.loadtxt(file_path)
                        mean_val = round(np.mean(data), 2)
                        std_val = round(np.std(data), 2)
                        min_val = round(np.min(data), 2)
                        max_val = round(np.max(data), 2)
                        total_fixels = len(data)

                        folder_statistics.append({
                            "Tract": tract_hemi,
                            "Segment": folder_name,
                            "Subject": subject_id,
                            "Mean FD": mean_val,
                            "Std FD": std_val,
                            "Min FD": min_val,
                            "Max FD": max_val,
                            "Num Fixels": total_fixels
                        })

                    except Exception as e:
                        print(f"❌ Error reading {file_path}: {e}")

            # Merge with demographics
            stats_df = pd.DataFrame(folder_statistics)
            if stats_df.empty:
                print(f"⚠️ No data found in {folder_path}")
                continue

            merged_df = pd.merge(stats_df, demographics_df, on='Subject', how='left')

            # Save per-segment CSV
            output_csv = os.path.join(folder_path, f"{folder_name}_unfiltered_statistics.csv")
            merged_df.to_csv(output_csv, index=False)
            print(f"✅ Saved: {output_csv}")

            # Append to global list
            all_statistics.extend(merged_df.to_dict(orient='records'))

# Save combined CSV for all tracts
combined_df = pd.DataFrame(all_statistics)
combined_output_csv = os.path.join(base_dir, "all_unfiltered_statistics_ALL_TRACTS.csv")
combined_df.to_csv(combined_output_csv, index=False)
print(f"\n📦 Combined file saved to: {combined_output_csv}")