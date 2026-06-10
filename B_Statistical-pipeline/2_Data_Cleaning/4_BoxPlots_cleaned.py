#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FD Retained Boxplots by Tract Category (Association, Projection, Commissural)
----------------------------------------------------------------------------

- Two columns per figure
- Large, readable panels for each tract
- Shared legend at bottom right (except for Commissural)
- Alphabetical panel labels (A, B, C...)
- High-resolution PNG outputs (crisp, publication-quality)
"""

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import os
import numpy as np
import string  # for alphabetical labels

# ===============================
# Load data
# ===============================
df = pd.read_csv('/PATH/TO/INPUT/merged_output_parsed_combined_filtered.csv')

# Clean and extract
df['Tract'] = df['Tract'].astype(str).str.strip()
df['Segment'] = df['Tract'].str.extract(r'_(\d+)$').astype(float).astype('Int64')
df['Tract_Base'] = df['Tract'].str.extract(r'^(.+)_\d+$')[0]

# Identify hemisphere
def get_hemi(name):
    if isinstance(name, str):
        if name.endswith('_left'):
            return 'Left'
        elif name.endswith('_right'):
            return 'Right'
        else:
            return 'Unknown'
    return 'Unknown'

df['Hemisphere'] = df['Tract_Base'].apply(get_hemi)

# Clean tract name (no hemisphere suffix)
df['Tract_Name'] = (
    df['Tract_Base']
    .str.replace('_left', '', regex=False)
    .str.replace('_right', '', regex=False)
)

# ===============================
# Define tract categories and order
# ===============================
association_order = ['AF', 'IFO', 'ILF', 'CG', 'SLF_I', 'SLF_II', 'SLF_III']
projection_order = ['CST', 'FPT', 'POPT']
commissural_order = [f'CC_{i}' for i in range(1, 8)]

categories = {
    'Association': association_order,
    'Projection': projection_order,
    'Commissural': commissural_order
}

# Colors
palette = {'Left': '#4C72B0', 'Right': '#DD8452', 'Unknown': 'gray'}

# ===============================
# Output directory
# ===============================
output_dir = '/PATH/TO/OUTPUT/boxplots_thresholdedFD_after_cleaning'
os.makedirs(output_dir, exist_ok=True)

# ===============================
# Set general plotting parameters for high-res
# ===============================
sns.set(style="whitegrid", context="talk", font_scale=1.0)
plt.rcParams['figure.dpi'] = 200
plt.rcParams['savefig.dpi'] = 600
plt.rcParams['savefig.format'] = 'png'
plt.rcParams['savefig.transparent'] = False
plt.rcParams['savefig.bbox'] = 'tight'
plt.rcParams['savefig.pad_inches'] = 0.05

# ===============================
# Plotting function with alphabetical labels
# ===============================
def plot_category(category_name, tract_list, show_legend=True):
    n_tracts = len(tract_list)
    ncols = 2
    nrows = int(np.ceil(n_tracts / ncols))

    # Large figure: 9x6 inches per subplot
    fig, axes = plt.subplots(
        nrows=nrows, ncols=ncols,
        figsize=(ncols * 9, nrows * 6),
        sharey=True
    )
    axes = axes.flatten()

    # Generate labels: A, B, C...
    labels = list(string.ascii_uppercase)

    for i, tract in enumerate(tract_list):
        ax = axes[i]
        tract_df = df[df['Tract_Name'] == tract]
        if tract_df.empty:
            ax.axis('off')
            continue

        sns.boxplot(
            data=tract_df,
            x='Segment',
            y='FD_Retained_Percent',
            hue='Hemisphere',
            palette=palette,
            ax=ax
        )
        ax.set_title(f'{tract}', fontsize=20, fontweight='bold')
        ax.set_xlabel('Segment', fontsize=16)
        ax.set_ylabel('% FD Retained', fontsize=16)
        ax.tick_params(labelsize=14)
        ax.set_ylim(0, 105)
        ax.get_legend().remove()

        # Add alphabetical panel label at top-left
        label_text = labels[i] if i < len(labels) else ''
        ax.text(
            -0.1, 1.05, label_text,
            transform=ax.transAxes,
            fontsize=22,
            fontweight='bold',
            va='top',
            ha='right'
        )

    # Hide unused axes
    for j in range(i + 1, len(axes)):
        axes[j].axis('off')

    plt.suptitle(f'{category_name} Tracts: FD Retained % per Segment (after cleaning)',
                 fontsize=26, fontweight='bold', y=0.995)

    # Shared legend (bottom right)
    if show_legend:
        handles, labels_legend = ax.get_legend_handles_labels()
        if handles:
            fig.legend(
                handles, labels_legend,
                title='Hemisphere',
                loc='lower right',
                bbox_to_anchor=(0.98, 0.03),
                frameon=True,
                fontsize=16,
                title_fontsize=16
            )

    plt.tight_layout(rect=[0, 0.05, 1, 0.96])

    # Save figure as high-resolution PNG
    output_path = os.path.join(output_dir, f'{category_name}_FD_Retained_ThresholdedFD_After_Cleaning.png')
    fig.set_dpi(600)
    plt.savefig(output_path, dpi=600, bbox_inches='tight', pad_inches=0.05)
    plt.close(fig)

# ===============================
# Generate plots
# ===============================
plot_category('Association', association_order, show_legend=True)
plot_category('Projection', projection_order, show_legend=True)
plot_category('Commissural', commissural_order, show_legend=False)
