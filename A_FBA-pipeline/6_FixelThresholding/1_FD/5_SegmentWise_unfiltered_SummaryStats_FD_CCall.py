import os
import numpy as np
import pandas as pd
import openpyxl

# Set base directory and demographics path
base_dir = "/Users/mervynsingh/Desktop/ALONG_TRACT/template_tractseg_new/segmentations/NEW"
demographics_excel_path = "/Users/mervynsingh/Desktop/ALONG_TRACT/template_tractseg_new/demographics.xlsx"

# CC tracts without hemispheres
cc_tracts = [f"CC_{i}" for i in range(1, 8)]

# Load demographics
if not os.path.isfile(demographics_excel_path):
    raise FileNotFoundError(f"Demographics file not found: {demographics_excel_path}")
demographics_df = pd.read_excel(demographics_excel_path)

all_statistics = []

for tract in cc_tracts:
    root_dir = os.path.join(base_dir, tract, "fixel_masks_fd")

    if not os.path.isdir(root_dir):
        print(f"⚠️ Skipping missing tract directory: {root_dir}")
        continue

    for folder_name in sorted(os.listdir(root_dir)):
        if not folder_name.startswith(tract + "_"):
            continue

        folder_path = os.path.join(root_dir, folder_name)
        if not os.path.isdir(folder_path):
            continue

        fixel_folders = sorted([f for f in os.listdir(folder_path) if f.startswith(f"fd_{tract}_")])

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
                        "Tract": tract,
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

        if not folder_statistics:
            print(f"⚠️ No data found in {folder_path}")
            continue

        stats_df = pd.DataFrame(folder_statistics)
        merged_df = pd.merge(stats_df, demographics_df, on='Subject', how='left')

        output_csv = os.path.join(folder_path, f"{folder_name}_unfiltered_statistics.csv")
        merged_df.to_csv(output_csv, index=False)
        print(f"✅ Saved: {output_csv}")

        all_statistics.extend(merged_df.to_dict(orient='records'))

# Save combined CSV for all CC tracts
combined_df = pd.DataFrame(all_statistics)
combined_output_csv = os.path.join(base_dir, "all_unfiltered_statistics_CC_only.csv")
combined_df.to_csv(combined_output_csv, index=False)
print(f"\n📦 Combined CC file saved to: {combined_output_csv}")