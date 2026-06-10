import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import subprocess
import gc

# === USER CONFIGURATION ===
root_dir = "/PATH/TO/DIRECTORY/template/segmentations/unthresholded_logfc_masks"
output_dir = "/PATH/TO/DIRECTORY/template/segmentations/histograms_unthresholded_logfc"

os.makedirs(output_dir, exist_ok=True)

for tract in sorted(os.listdir(root_dir)):
    tract_path = os.path.join(root_dir, tract)
    if not os.path.isdir(tract_path):
        continue

    mif_files = sorted([
    f for f in os.listdir(tract_path)
    if f.endswith(".mif") and f not in ["index.mif", "directions.mif"]
])
    if not mif_files:
        print(f"No .mif files found in {tract_path}")
        continue

    pdf_path = os.path.join(output_dir, f"{tract}_unthresholded_logfc_histograms.pdf")

    with PdfPages(pdf_path) as pdf:
        for i in range(0, len(mif_files), 10):

            fig, axes = plt.subplots(5, 2, figsize=(11, 14))
            axes = axes.flatten()

            for ax, filename in zip(axes, mif_files[i:i+10]):
                file_path = os.path.join(tract_path, filename)

                try:
                    # Pipe mrdump output directly
                    result = subprocess.run(
                        ["mrdump", file_path],
                        capture_output=True,
                        text=True,
                        check=True
                    )

                    data = np.fromstring(result.stdout, sep=" ")

                    # Remove zeros (background)
                    data = data[data != 0]

                    # Remove NaNs if present
                    data = data[~np.isnan(data)]

                    if data.size == 0:
                        raise ValueError("Empty after filtering")

                    ax.hist(data, bins=50)
                    mean_val = np.mean(data)
                    num_fixels = len(data)

                    ax.axvline(mean_val, linestyle='dotted', linewidth=1.5)

                    annotation = f"Fixels: {num_fixels}\nMean: {mean_val:.5f}"
                    ax.text(
                        0.95, 0.95, annotation,
                        verticalalignment='top',
                        horizontalalignment='right',
                        transform=ax.transAxes,
                        fontsize=9,
                        bbox=dict(boxstyle="round,pad=0.3",
                                  facecolor="white",
                                  edgecolor="black")
                    )

                    ax.set_title(filename, fontsize=9)
                    ax.set_xlabel("log FC value")
                    ax.set_ylabel("Count")

                except Exception as e:
                    ax.set_title(f"{filename} (error)", fontsize=9)
                    print(f"Error processing {filename}: {e}")

            # Remove unused subplots
            for j in range(len(mif_files[i:i+10]), 10):
                fig.delaxes(axes[j])

            fig.tight_layout()
            pdf.savefig(fig)
            plt.close(fig)
            gc.collect()

print("✅ All .mif log FC histograms generated successfully.")