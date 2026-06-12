#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Association Tracts FD/FC effect size overlays (both hemispheres)
----------------------------------------------------------------
- Saves individual PNGs per tract × metric
- Each image shows both left + right hemisphere tracts together
- Overlays colored tracts on a grayscale background brain
- Transparent outside brain
- Radiological convention (L on right)
"""

import os
import glob
import numpy as np
import pandas as pd
import nibabel as nib
import matplotlib.pyplot as plt
from matplotlib import colors
import matplotlib.image as mpimg
from skimage.transform import resize

# ==========================
# Paths
# ==========================
fd_csv_path = "/PATH/TO/INPUT/AssocProj_ModelSummaries_Reduced_Full_TDS_FD.csv"
fc_csv_path = "/PATH/TO/INPUT/AssocProj_ModelSummaries_Reduced_Full_TDS_FC.csv"

mask_dir = "/PATH/TO/INPUT/tract_masks"
output_dir = "/PATH/TO/OUTPUT/Association_tracts_full"
background_img_path = "/PATH/TO/INPUT/axial.png"  # Update if needed

# read both CSVs and concatenate
df_fd = pd.read_csv(fd_csv_path)
df_fc = pd.read_csv(fc_csv_path)
df_fd["Metric"] = "FD"
df_fc["Metric"] = "FC"
df = pd.concat([df_fd, df_fc], ignore_index=True)
os.makedirs(output_dir, exist_ok=True)

# ==========================
# Configuration
# ==========================

assoc_tracts = ["AF", "CG", "IFO", "ILF", "SLF_I", "SLF_II", "SLF_III"]
hemispheres = ["left", "right"]
metrics = ["FD", "FC"]

# ==========================
# subset Age effect and Model
# ==========================
df = df[df["term"] == "AgeAtScan"]
# Filter to only Full model
df = df[df["Model"] == "Full"]
df["Tract"] = df["Tract"].astype(str).str.strip()
df["Metric"] = df["Metric"].astype(str).str.strip()
df["estimate"] = pd.to_numeric(df["estimate"], errors="coerce")

# Universal symmetric color scale
abs_max = np.max(np.abs(df["estimate"]))
vmin, vmax = -abs_max, abs_max
norm = colors.TwoSlopeNorm(vmin=vmin, vcenter=0, vmax=vmax)
cmap = plt.cm.coolwarm

# ==========================
# Load and prepare background brain image
# ==========================
bg_img = mpimg.imread(background_img_path)
if bg_img.ndim == 3:
    bg_img = np.mean(bg_img[..., :3], axis=-1)
bg_img = bg_img / np.max(bg_img)
bg_img = np.flipud(bg_img)  # correct upside-down orientation

# ==========================
# Iterate over tracts × metrics
# ==========================
for tract in assoc_tracts:
    for metric in metrics:
        # Combine both hemispheres on one canvas
        canvas = None
        base_shape = None

        for hemi in hemispheres:
            subset = df[(df["Tract"] == tract) &
                        (df["Hemisphere"] == hemi) &
                        (df["Metric"] == metric)]
            if subset.empty:
                continue

            # Get first mask to define shape
            first_mask = None
            for seg in subset["Segment"].unique():
                mask_pattern = os.path.join(mask_dir, f"{tract}_{hemi}_{seg}_mask.nii*")
                mask_files = glob.glob(mask_pattern)
                if mask_files:
                    first_mask = mask_files[0]
                    break
            if first_mask is None:
                continue

            mask_3d = nib.load(first_mask).get_fdata()
            mask_mip = np.max(mask_3d, axis=2)
            mask_mip = np.rot90(mask_mip, k=1)
            mask_mip = np.fliplr(mask_mip)
            mask_mip = np.flipud(mask_mip)

            if base_shape is None:
                base_shape = mask_mip.shape
                canvas = np.zeros(base_shape)

            # Apply segment values
            for _, row in subset.iterrows():
                seg = row["Segment"]
                estimate = row["estimate"]
                mask_pattern = os.path.join(mask_dir, f"{tract}_{hemi}_{seg}_mask.nii*")
                mask_files = glob.glob(mask_pattern)
                if not mask_files:
                    continue
                mask_3d = nib.load(mask_files[0]).get_fdata()
                mask_mip = np.max(mask_3d, axis=2)
                mask_mip = np.rot90(mask_mip, k=1)
                mask_mip = np.fliplr(mask_mip)
                mask_mip = np.flipud(mask_mip)

                if mask_mip.shape == canvas.shape:
                    canvas[mask_mip > 0] = estimate

        if canvas is None or np.all(canvas == 0):
            print(f"Skipping {tract} ({metric}) – no data")
            continue

        # Resize background
        bg_resized = resize(bg_img, canvas.shape, preserve_range=True)

        # RGBA overlay
        tract_colors = cmap(norm(canvas))
        tract_colors[..., 3] = (canvas != 0).astype(float) * 0.9  # semi-transparent

        # Plot overlay
        fig, ax = plt.subplots(figsize=(6, 6), dpi=300)
        ax.imshow(bg_resized, cmap="gray", origin="lower")
        ax.imshow(tract_colors, origin="lower")
        ax.axis("off")

        # Save PNG
        output_file = os.path.join(output_dir, f"{tract}_{metric}_axial_v2_full.png")
        plt.savefig(output_file, bbox_inches="tight", pad_inches=0, transparent=True)
        plt.close(fig)
        print(f"✅ Saved: {output_file}")

print("\nAll association tract overlays (both hemispheres) saved with anatomical background.")
