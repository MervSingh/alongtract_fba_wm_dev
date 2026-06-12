# -*- coding: utf-8 -*-
import re
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

# ---- Load your data ----
df = pd.read_csv('/PATH/TO/INPUT/highest_second_bin_values_fd_tracts.csv')
df.rename(columns={'Threshold criteria': 'Threshold'}, inplace=True)

# ---- Preprocess ----
def split_tract_name(name):
    name = str(name)
    if name.startswith('CC_'):
        match = re.match(r'CC_(\d+)_(\d+)', name)
        if match:
            tract_num = match.group(1)
            segment = match.group(2)
            return f'CC{tract_num}', None, int(segment), 'CC'

    match = re.match(r'(?P<Tract>[A-Z]+(?:_[A-Z]+)?)_(?P<Hemi>left|right)?_?(?P<Segment>\d+)?', name)
    if match:
        tract = match.group('Tract')
        hemi = match.group('Hemi')
        segment = match.group('Segment')
        return tract, hemi, int(segment) if segment is not None else None, 'Non-CC'
    
    return None, None, None, 'Unknown'

# Apply parsing
df[['TractName', 'Hemi', 'Segment', 'TractType']] = df['Folder'].apply(lambda x: pd.Series(split_tract_name(x)))

# Reorder columns
cols = ['TractName', 'Hemi', 'Segment', 'TractType'] + [c for c in df.columns if c not in ['TractName', 'Hemi', 'Segment', 'TractType']]
df = df[cols]

# ---- Color schemes ----
hemi_colors = {"Left": "steelblue", "Right": "darkorange"}
cc_colors = {
    "CC1": "red", "CC2": "green", "CC3": "blue",
    "CC4": "purple", "CC5": "orange", "CC6": "brown", "CC7": "pink"
}

# ---- Get unique tracts ----
non_cc_tracts = df[df['TractType'] != 'CC']['TractName'].unique()
cc_tracts = df[df['TractType'] == 'CC']['TractName'].unique()

# ---- Save plots to PDF ----
pdf_path = '/PATH/TO/OUTPUT/tract_thresholds.pdf'
with PdfPages(pdf_path) as pdf:
    
    all_tracts = list(non_cc_tracts) + ['CC_all']
    plots_per_page = 3

    for i in range(0, len(all_tracts), plots_per_page):
        fig, axes = plt.subplots(plots_per_page, 1, figsize=(8, 5*plots_per_page), sharex=False)
        axes = axes.flatten() if plots_per_page > 1 else [axes]

        for j, tract in enumerate(all_tracts[i:i+plots_per_page]):
            ax = axes[j]
            
            if tract == 'CC_all':
                # Plot all CC tracts together
                for cc in cc_tracts:
                    cc_df = df[df['TractName'] == cc].sort_values('Segment')
                    color = cc_colors.get(cc, 'gray')
                    ax.plot(cc_df['Segment'], cc_df['Threshold'], marker='o', linestyle='-', color=color, label=cc)
                    # Min/max markers
                    min_idx = cc_df['Threshold'].idxmin()
                    max_idx = cc_df['Threshold'].idxmax()
                    ax.plot(cc_df.loc[min_idx, 'Segment'], cc_df.loc[min_idx, 'Threshold'], 'v', color=color)
                    ax.plot(cc_df.loc[max_idx, 'Segment'], cc_df.loc[max_idx, 'Threshold'], '^', color=color)
                ax.set_title('CC Tracts')
            
            else:
                tract_df = df[df['TractName'] == tract]
                for hemi, color in zip(['left', 'right'], [hemi_colors['Left'], hemi_colors['Right']]):
                    hemi_df = tract_df[tract_df['Hemi'] == hemi]
                    if not hemi_df.empty:
                        hemi_df = hemi_df.sort_values('Segment')
                        ax.plot(hemi_df['Segment'], hemi_df['Threshold'], marker='o', linestyle='-', color=color, label=hemi.capitalize())
                        # Min/max markers
                        min_idx = hemi_df['Threshold'].idxmin()
                        max_idx = hemi_df['Threshold'].idxmax()
                        ax.plot(hemi_df.loc[min_idx, 'Segment'], hemi_df.loc[min_idx, 'Threshold'], 'v', color=color)
                        ax.plot(hemi_df.loc[max_idx, 'Segment'], hemi_df.loc[max_idx, 'Threshold'], '^', color=color)
                ax.set_title(tract)
            
            ax.set_xlabel('Segment')
            ax.set_ylabel('Threshold')
            ax.set_xlim(1, 20)  # fixed x-axis from 1 to 20
            ax.set_xticks(range(1, 21))
            ax.grid(True, linestyle='--', alpha=0.5)
            ax.legend()
        
        plt.tight_layout(rect=[0, 0, 1, 0.95])
        pdf.savefig(fig)
        plt.close(fig)

print(f'PDF saved to {pdf_path}')
