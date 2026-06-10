# -*- coding: utf-8 -*-
"""

"""

import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import os


# ---- Load model results ----
df_cc = pd.read_csv('/PATH/TO/INPUT/AssocProj_ModelSummaries_Reduced_Full_TDS_FC.csv')
df_other = pd.read_csv('/PATH/TO/INPUT/CC_ModelSummaries_Reduced_Full_TDS_FC.csv')

# Combine in memory
df = pd.concat([df_cc, df_other], ignore_index=True)

# keep only Reduced model results
df = df[df['Model'] == 'Reduced']
# Keep only AgeAtScan term
df = df[df['term'] == 'AgeAtScan']

# Clean columns
df['Tract'] = df['Tract'].astype(str).str.strip()
df['Hemisphere'] = df['Hemisphere'].str.capitalize()  # "Left"/"Right"

# ---- Plotting ----
output_pdf = '/PATH/TO/OUTPUT/AgeAtScan_FC_lineplots_Reduced_v2.pdf'
os.makedirs(os.path.dirname(output_pdf), exist_ok=True)

hemi_colors = {"Left": "steelblue", "Right": "darkorange"}
cc_colors = {
    "CC1": "red", "CC2": "green", "CC3": "blue",
    "CC4": "purple", "CC5": "orange", "CC6": "brown", "CC7": "pink"
}

cc_tracts = [t for t in df['Tract'].unique() if t.startswith("CC")]
other_tracts = [t for t in df['Tract'].unique() if t not in cc_tracts]

with PdfPages(output_pdf) as pdf:
    # --- CC tracts ---
    if cc_tracts:
        fig, ax = plt.subplots(figsize=(12, 6))
        for cc in cc_tracts:
            cc_data = df[df['Tract'] == cc].sort_values('Segment')
            lower = cc_data['estimate'] - 1.96 * cc_data['std.error']
            upper = cc_data['estimate'] + 1.96 * cc_data['std.error']
            ax.plot(cc_data['Segment'], cc_data['estimate'],
                    linestyle='-', color=cc_colors[cc], alpha=0.8, label=cc)
            ax.fill_between(cc_data['Segment'], lower, upper, color=cc_colors[cc], alpha=0.2)
        ax.axhline(0, color='gray', linestyle='--', linewidth=1)
        ax.set_xlabel("Segment")
        ax.set_ylabel("Age change in Mean FC")
        ax.set_title("Corpus Callosum (CC1–CC7) Age Effects")
        ax.set_xticks(range(1, 21))
        ax.set_xticklabels([str(x) for x in range(1, 21)])
        ax.set_xlim(1, 20)
        ax.legend(fontsize=8)
        fig.tight_layout()
        pdf.savefig(fig)
        plt.close(fig)

    # --- Other tracts: Left + Right ---
    n_per_page = 3
    for i in range(0, len(other_tracts), n_per_page):
        subset = other_tracts[i:i+n_per_page]
        # Remove sharex=True so each subplot has its own x-axis
        fig, axes = plt.subplots(len(subset), 1, figsize=(10, 4*len(subset)))
        if len(subset) == 1:
            axes = [axes]
        for ax, tract_name in zip(axes, subset):
            tract_data = df[df['Tract'] == tract_name].sort_values('Segment')
            for hemi in ["Left", "Right"]:
                hemi_data = tract_data[tract_data['Hemisphere'] == hemi]
                if not hemi_data.empty:
                    lower = hemi_data['estimate'] - 1.96 * hemi_data['std.error']
                    upper = hemi_data['estimate'] + 1.96 * hemi_data['std.error']
                    ax.plot(hemi_data['Segment'], hemi_data['estimate'],
                            linestyle='-', color=hemi_colors[hemi], label=hemi)
                    ax.fill_between(hemi_data['Segment'], lower, upper,
                                    color=hemi_colors[hemi], alpha=0.2)
            ax.axhline(0, color='gray', linestyle='--', linewidth=1)
            ax.set_title(tract_name)
            ax.set_xlabel("Segment")
            ax.set_ylabel("Age change in Mean FC")
            ax.set_xticks(range(1, 21))
            ax.set_xticklabels([str(x) for x in range(1, 21)])
            ax.set_xlim(1, 20)
            ax.legend(fontsize=8)
        fig.tight_layout()
        pdf.savefig(fig)
        plt.close(fig)

print(f"✅ Saved AgeAtScan line plots with CI and transparent CC lines PDF: {output_pdf}")
