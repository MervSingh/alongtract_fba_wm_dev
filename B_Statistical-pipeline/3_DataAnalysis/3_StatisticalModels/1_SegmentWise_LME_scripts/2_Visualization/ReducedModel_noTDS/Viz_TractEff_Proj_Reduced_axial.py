#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Projection Tracts FD/FC effect size overlays (CORONAL view)
-----------------------------------------------------------
- Matches association tract overlay pipeline
- Uses CSV effect estimates mapped onto segment masks
- Combines left + right hemispheres in one image
- Coronal projection
- Radiological convention (L on R)
- Upright anatomical orientation
- Transparent outside brain
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
fd_csv_path = "/PATH/TO/INPUT/AssocProj_ModelSummaries_Reduced_Full_TDS_FD.csv"
fc_csv_path = "/PATH/TO/INPUT/AssocProj_ModelSummaries_Reduced_Full_TDS_FC.csv"

mask_dir = "/PATH/TO/INPUT/tract_masks"
output_dir = "/PATH/TO/OUTPUT/Projection_tracts"
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

tract_list = ["CST", "FPT", "POPT"]
metrics = ["FD", "FC"]
hemispheres = ["left", "right"]

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
# Universal symmetric color scale
# ==========================

abs_max = np.max(np.abs(df["estimate"]))

vmin, vmax = -abs_max, abs_max

norm = colors.TwoSlopeNorm(
    vmin=vmin,
    vcenter=0,
    vmax=vmax
)

cmap = plt.cm.coolwarm

# ==========================
# Load background image
# ==========================

bg_img = mpimg.imread(background_img_path)

if bg_img.ndim == 3:
    bg_img = np.mean(bg_img[..., :3], axis=-1)

bg_img = bg_img / np.max(bg_img)

# Radiological convention
bg_img = np.fliplr(bg_img)

# Upright orientation
bg_img = np.flipud(bg_img)

# ==========================
# Iterate over tracts × metrics
# ==========================

for tract in tract_list:

    for metric in metrics:

        canvas = None
        base_shape = None

        # ==========================
        # Process hemispheres
        # ==========================

        for hemi in hemispheres:

            subset = df[
                (df["Tract"] == tract) &
                (df["Hemisphere"] == hemi) &
                (df["Metric"] == metric)
            ]

            if subset.empty:
                continue

            # ==========================
            # Get first mask for shape
            # ==========================

            first_mask = None

            for seg in subset["Segment"].unique():

                mask_pattern = os.path.join(
                    mask_dir,
                    f"{tract}_{hemi}_{seg}_mask.nii*"
                )

                mask_files = glob.glob(mask_pattern)

                if mask_files:
                    first_mask = mask_files[0]
                    break

            if first_mask is None:
                continue

            # ==========================
            # Define canvas shape
            # ==========================

            mask_3d = nib.load(first_mask).get_fdata()

            # --- CORONAL MIP ---
            mask_mip = np.max(mask_3d, axis=1)

            # Anatomical orientation
            mask_mip = np.rot90(mask_mip, k=1)

            # Radiological convention
            mask_mip = np.fliplr(mask_mip)

            # Upright orientation
            mask_mip = np.flipud(mask_mip)

            if base_shape is None:

                base_shape = mask_mip.shape

                canvas = np.zeros(base_shape)

            # ==========================
            # Apply segment estimates
            # ==========================

            for _, row in subset.iterrows():

                seg = row["Segment"]

                estimate = row["estimate"]

                mask_pattern = os.path.join(
                    mask_dir,
                    f"{tract}_{hemi}_{seg}_mask.nii*"
                )

                mask_files = glob.glob(mask_pattern)

                if not mask_files:
                    continue

                mask_3d = nib.load(mask_files[0]).get_fdata()

                # --- CORONAL MIP ---
                mask_mip = np.max(mask_3d, axis=1)

                # Anatomical orientation
                mask_mip = np.rot90(mask_mip, k=1)

                # Radiological convention
                mask_mip = np.fliplr(mask_mip)

                # Upright orientation
                mask_mip = np.flipud(mask_mip)

                # ==========================
                # Fill segment with estimate
                # ==========================

                if mask_mip.shape == canvas.shape:

                    canvas[mask_mip > 0] = estimate

        # ==========================
        # Skip empty maps
        # ==========================

        if canvas is None or np.all(canvas == 0):

            print(f"Skipping {tract} ({metric}) – no data")

            continue

        # ==========================
        # Resize background
        # ==========================

        bg_resized = resize(
            bg_img,
            canvas.shape,
            preserve_range=True
        )

        # ==========================
        # RGBA overlay
        # ==========================

        tract_colors = cmap(norm(canvas))

        tract_colors[..., 3] = (
            (canvas != 0).astype(float) * 0.9
        )

        # ==========================
        # Plot overlay
        # ==========================

        fig, ax = plt.subplots(
            figsize=(6, 6),
            dpi=300
        )

        ax.imshow(
            bg_resized,
            cmap="gray",
            origin="lower"
        )

        ax.imshow(
            tract_colors,
            origin="lower"
        )

        ax.axis("off")

        # ==========================
        # Save PNG
        # ==========================

        output_file = os.path.join(
            output_dir,
            f"{tract}_{metric}_coronal_v2.png"
        )

        plt.savefig(
            output_file,
            bbox_inches="tight",
            pad_inches=0,
            transparent=True
        )

        plt.close(fig)

        print(f"✅ Saved: {output_file}")

print("\n✅ All projection tract overlays saved in CORONAL orientation.")