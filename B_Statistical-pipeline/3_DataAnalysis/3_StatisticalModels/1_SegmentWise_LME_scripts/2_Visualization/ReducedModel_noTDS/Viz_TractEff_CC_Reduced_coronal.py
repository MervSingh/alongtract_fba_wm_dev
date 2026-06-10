#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Corpus Callosum FD/FC effect size overlays (CORONAL view, NO HEMISPHERE)
------------------------------------------------------------------------
- Uses CSV estimates (CC1–CC7)
- Maps to mask filenames (CC_1–CC_7)
- No hemisphere splitting (full CC masks)
- Coronal projection
- Radiological convention (L on R)
- Publication-ready overlay pipeline
"""

import os
import glob
import numpy as np
import pandas as pd
import nibabel as nib
import matplotlib.pyplot as plt
import matplotlib.image as mpimg

from matplotlib import colors
from skimage.transform import resize

# ==========================
# Paths
# ==========================
fd_csv_path = "/PATH/TO/INPUT/CC_ModelSummaries_Reduced_Full_TDS_FD.csv"
fc_csv_path = "/PATH/TO/INPUT/CC_ModelSummaries_Reduced_Full_TDS_FC.csv"

mask_dir = "/PATH/TO/INPUT/tract_masks"
output_dir = "/PATH/TO/OUTPUT/CC_tracts"
background_img_path = "/PATH/TO/INPUT/coronal.png"  # Update if needed

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

cc_tracts = ["CC1", "CC2", "CC3", "CC4", "CC5", "CC6", "CC7"]
metrics = ["FD", "FC"]

# ==========================
# subset Age effect and Model
# ==========================
df = df[df["term"] == "AgeAtScan"]
# Filter to only Reduced model
df = df[df["Model"] == "Reduced"]
df["Tract"] = df["Tract"].astype(str).str.strip()
df["Metric"] = df["Metric"].astype(str).str.strip()
df["estimate"] = pd.to_numeric(df["estimate"], errors="coerce")


# ==========================
# Color scaling
# ==========================

abs_max = np.max(np.abs(df["estimate"]))

norm = colors.TwoSlopeNorm(
    vmin=-abs_max,
    vcenter=0,
    vmax=abs_max
)

cmap = plt.cm.coolwarm

# ==========================
# Background
# ==========================

bg_img = mpimg.imread(background_img_path)

if bg_img.ndim == 3:
    bg_img = np.mean(bg_img[..., :3], axis=-1)

bg_img = bg_img / np.max(bg_img)

bg_img = np.fliplr(bg_img)
bg_img = np.flipud(bg_img)

# ==========================
# CC mapping (CSV → mask naming)
# ==========================

def cc_to_mask(tract):
    return tract.replace("CC", "CC_")

# ==========================
# Main loop
# ==========================

for tract in cc_tracts:

    mask_tract = cc_to_mask(tract)

    for metric in metrics:

        subset = df[
            (df["Tract"] == tract) &
            (df["Metric"] == metric)
        ]

        if subset.empty:
            print(f"Skipping {tract} ({metric}) – no data")
            continue

        canvas = None
        base_shape = None

        for seg in subset["Segment"].unique():

            mask_pattern = os.path.join(
                mask_dir,
                f"{mask_tract}_{seg}_mask.nii*"
            )

            mask_files = glob.glob(mask_pattern)

            if not mask_files:
                continue

            mask_3d = nib.load(mask_files[0]).get_fdata()

            # ==========================
            # CORONAL MIP
            # ==========================
            mask_mip = np.max(mask_3d, axis=1)
            mask_mip = np.rot90(mask_mip, k=1)
            mask_mip = np.fliplr(mask_mip)
            mask_mip = np.flipud(mask_mip)

            if base_shape is None:
                base_shape = mask_mip.shape
                canvas = np.zeros(base_shape)

            # ==========================
            # Get estimate
            # ==========================
            row = subset[subset["Segment"] == seg]

            if row.empty:
                continue

            estimate = row["estimate"].values[0]

            # ==========================
            # Fill canvas
            # ==========================
            if mask_mip.shape == canvas.shape:
                canvas[mask_mip > 0] = estimate

        # ==========================
        # Skip empty
        # ==========================
        if canvas is None or np.all(canvas == 0):
            print(f"Skipping {tract} ({metric}) – no data")
            continue

        # ==========================
        # Background resize
        # ==========================
        bg_resized = resize(bg_img, canvas.shape, preserve_range=True)

        # ==========================
        # Overlay
        # ==========================
        tract_colors = cmap(norm(canvas))
        tract_colors[..., 3] = (canvas != 0).astype(float) * 0.9

        # ==========================
        # Plot
        # ==========================
        fig, ax = plt.subplots(figsize=(6, 6), dpi=300)

        ax.imshow(bg_resized, cmap="gray", origin="lower")
        ax.imshow(tract_colors, origin="lower")
        ax.axis("off")

        # ==========================
        # Save
        # ==========================
        outpath = os.path.join(
            output_dir,
            f"{tract}_{metric}_coronal_v2.png"
        )

        plt.savefig(
            outpath,
            bbox_inches="tight",
            pad_inches=0,
            transparent=True
        )

        plt.close(fig)

        print(f"✅ Saved: {outpath}")

print("\n✅ CC coronal NO-HEMISPHERE pipeline complete.")