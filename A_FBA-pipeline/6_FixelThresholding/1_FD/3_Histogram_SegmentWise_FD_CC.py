import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages

# Base root directory where all tracts are located
base_dir = "/PATH/TO/DIRECTORY/template/segmentations"

cc_tracts = [f"CC_{i}" for i in range(1, 8)]

skipped_empty_files = []
all_second_bin_values = []
all_highest_second_bin_per_folder = []

for tract_name in cc_tracts:
    root_dir = os.path.join(base_dir, tract_name, "fixel_masks_fd")

    if not os.path.isdir(root_dir):
        print(f"Skipping missing tract: {tract_name}")
        continue

    for folder_num in range(1, 21):
        folder_name = f"{tract_name}_{folder_num}"
        folder_path = os.path.join(root_dir, folder_name)

        if not os.path.isdir(folder_path):
            print(f"Skipping missing folder: {folder_name}")
            continue

        pdf_path = os.path.join(folder_path, f"subject_histograms_{folder_name}.pdf")
        subfolder_list = sorted([f for f in os.listdir(folder_path) if f.startswith(f"fd_{tract_name}_")])
        subject_data = []

        highest_bin_value = -np.inf
        highest_subject = None
        second_bin_values = []

        for subfolder in subfolder_list:
            subfolder_path = os.path.join(folder_path, subfolder)
            if not os.path.isdir(subfolder_path):
                continue

            txt_files = sorted([f for f in os.listdir(subfolder_path) if f.endswith(".txt")])
            for txt_file in txt_files:
                subject_id = txt_file.split(".")[0]
                file_path = os.path.join(subfolder_path, txt_file)

                if os.path.getsize(file_path) == 0:
                    print(f"⚠️ Skipping empty file: {file_path}")
                    skipped_empty_files.append(file_path)
                    continue

                try:
                    data = np.loadtxt(file_path)
                    subject_data.append((subject_id, data))
                except Exception as e:
                    print(f"❌ Error reading {file_path}: {e}")
                    continue

        with PdfPages(pdf_path) as pdf:
            fig, ax = plt.subplots(figsize=(14, 11))
            ax.set_frame_on(False)
            ax.set_xticks([])
            ax.set_yticks([])
            ax.text(0.5, 0.5, f"Fixel Density Histograms\n{folder_name}", fontsize=28, ha='center', va='center', fontweight='bold')
            pdf.savefig(fig)
            plt.close(fig)

            num_subjects = len(subject_data)
            subjects_per_page = 10
            num_pages = int(np.ceil(num_subjects / subjects_per_page))

            for page in range(num_pages):
                fig, axes = plt.subplots(5, 2, figsize=(16, 20), constrained_layout=True)
                axes = axes.flatten()

                for i in range(subjects_per_page):
                    idx = page * subjects_per_page + i
                    if idx >= num_subjects:
                        break

                    subject_id, data = subject_data[idx]
                    ax = axes[i]

                    hist_values, bin_edges, _ = ax.hist(data, bins=30, color='royalblue', edgecolor='black', alpha=0.7)

                    if len(bin_edges) > 2:
                        bin_start = bin_edges[0]
                        bin_end = bin_edges[2]
                        second_bin_fd_value = bin_edges[2]
                        range_fixels = np.sum((data >= bin_start) & (data <= bin_end))

                        second_bin_values.append([folder_name, subject_id, bin_start, bin_end, second_bin_fd_value, range_fixels])

                        if second_bin_fd_value > highest_bin_value:
                            highest_bin_value = second_bin_fd_value
                            highest_subject = subject_id

                        ax.axvspan(bin_start, bin_end, color='orange', alpha=0.3, label="1st - 2nd Bin Range")
                        ax.text((bin_start + bin_end) / 2, max(hist_values) * 0.9,
                                f"{bin_start:.4f} - {bin_end:.4f}\nFD Value: {second_bin_fd_value:.4f}\nRange Fixels: {range_fixels}",
                                fontsize=10, color='black', ha='center',
                                bbox=dict(facecolor='white', alpha=0.7))

                    mean_val = np.mean(data)
                    std_val = np.std(data)
                    min_val = np.min(data)
                    max_val = np.max(data)
                    num_zeros = np.sum(data == 0)
                    num_nonzeros = np.sum(data > 0)
                    total_fixels = num_zeros + num_nonzeros

                    ax.axvline(mean_val, color='red', linestyle='dashed', linewidth=2, label="Mean")
                    ax.set_title(f"Subject: {subject_id}", fontsize=16)
                    ax.set_xlabel("FD Value", fontsize=14)
                    ax.set_ylabel("Fixel Count", fontsize=14)

                    stats_text = (f"Mean: {mean_val:.2f}\nStd: {std_val:.2f}\nMin: {min_val:.2f}\n"
                                  f"Max: {max_val:.2f}\nZeros: {num_zeros}\nNon-zeros: {num_nonzeros}\nFixels: {total_fixels}")
                    ax.text(0.98, 0.95, stats_text, transform=ax.transAxes, fontsize=12,
                            verticalalignment='top', horizontalalignment='left',
                            bbox=dict(facecolor='white', alpha=0.7))

                    ax.legend(loc='upper right', bbox_to_anchor=(0.95, 0.95), fontsize=10)

                for j in range(i + 1, len(axes)):
                    fig.delaxes(axes[j])

                pdf.savefig(fig)
                plt.close(fig)

        print(f"✅ Saved histograms to {pdf_path}")
        all_second_bin_values.extend(second_bin_values)
        all_highest_second_bin_per_folder.append([folder_name, highest_subject, highest_bin_value])

# Save combined CSVs
combined_csv_path = os.path.join(base_dir, "second_bin_values_cc.csv")
pd.DataFrame(all_second_bin_values, columns=["Folder", "Subject", "First Bin Start", "Second Bin End", "Second Bin FD Value", "Range Fixel Count"]).to_csv(combined_csv_path, index=False)

highest_bin_csv_path = os.path.join(base_dir, "highest_second_bin_values_cc.csv")
pd.DataFrame(all_highest_second_bin_per_folder, columns=["Folder", "Subject", "Highest Second Bin Value"]).to_csv(highest_bin_csv_path, index=False)

# Log skipped empty files
if skipped_empty_files:
    skipped_log_path = os.path.join(base_dir, "CC_skipped_empty_files.txt")
    with open(skipped_log_path, "w") as f:
        for path in skipped_empty_files:
            f.write(path + "\n")
    print(f"\n⚠️ Skipped empty files logged to: {skipped_log_path}")

print(f"\n✅ All CC second bin values saved to: {combined_csv_path}")
print(f"✅ Highest CC second bin values saved to: {highest_bin_csv_path}")