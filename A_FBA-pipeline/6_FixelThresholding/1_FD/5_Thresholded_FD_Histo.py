import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

# === USER CONFIGURATION ===
root_dir = "/PATH/TO/DIRECTORY/template/segmentations/thresholded_fd_masks"
output_dir = "/PATH/TO/DIRECTORY/template/segmentations/histograms_thresholded_fd"

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

# Loop over each tract
for tract in sorted(os.listdir(root_dir)):
    tract_path = os.path.join(root_dir, tract)
    if not os.path.isdir(tract_path):
        continue

    # Filter only .txt files containing "masked"
    filtered_files = [f for f in sorted(os.listdir(tract_path)) if f.endswith(".txt") and "masked" in f]
    if not filtered_files:
        print(f"No masked .txt files found in {tract_path}")
        continue

    # PDF output path for this tract
    pdf_path = os.path.join(output_dir, f"{tract}_thresholded_logfc_histograms.pdf")
    with PdfPages(pdf_path) as pdf:
        for i in range(0, len(filtered_files), 10):
            fig, axes = plt.subplots(5, 2, figsize=(11, 14))  # 10 plots per page
            axes = axes.flatten()

            for ax, filename in zip(axes, filtered_files[i:i+10]):
                file_path = os.path.join(tract_path, filename)
                try:
                    data = np.loadtxt(file_path)
                    if data.size == 0:
                        raise ValueError("Empty file")

                    # Plot histogram
                    ax.hist(data, bins=50, color='gray', edgecolor='black')

                    # Calculate stats
                    mean_val = np.mean(data)
                    num_fixels = len(data)

                    # Red dotted mean line
                    ax.axvline(mean_val, color='red', linestyle='dotted', linewidth=1.5)

                    # Stats annotation
                    annotation = f"Fixels: {num_fixels}\nMean: {mean_val:.5f}"
                    ax.text(0.95, 0.95, annotation,
                            verticalalignment='top', horizontalalignment='right',
                            transform=ax.transAxes, fontsize=9,
                            bbox=dict(boxstyle="round,pad=0.3", facecolor="white", edgecolor="black"))

                    ax.set_title(filename, fontsize=10)
                    ax.set_xlabel("FD value")
                    ax.set_ylabel("Count")
                except Exception as e:
                    ax.set_title(f"{filename} (empty or error)", fontsize=10)
                    ax.set_xlabel("FD value")
                    ax.set_ylabel("Count")
                    ax.set_xlim(0, 1)
                    ax.set_ylim(0, 1)
                    print(f"Plotted empty histogram for: {filename} ({e})")

            # Hide unused subplots if fewer than 10
            for j in range(len(filtered_files[i:i+10]), 10):
                fig.delaxes(axes[j])

            fig.tight_layout()
            pdf.savefig(fig)
            plt.close(fig)

print("✅ All filtered FD histograms generated and saved with mean line and fixel count annotations.")
