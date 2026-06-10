import pandas as pd
import matplotlib.pyplot as plt
import os
import numpy as np

# ============================================================
# Load data
# ============================================================

df = pd.read_csv(
    '/ADD/PATH/TO/INPUT/merged_output_parsed_combined_filtered.csv'
)

df['TractName'] = df['TractName'].astype(str).str.strip()
df['Hemi'] = df['Hemi'].str.capitalize()

# ============================================================
# HARD LOCK: FC ONLY
# ============================================================

if 'MeanFC' not in df.columns:
    raise ValueError("MeanFC column not found. This script is FC-only.")

df = df[['TractName', 'Hemi', 'Segment', 'MeanFC']].copy()
df = df[df['MeanFC'].notna()]

df = df.rename(columns={'MeanFC': 'MeanValue'})

value_col = 'MeanValue'

# ============================================================
# Output path
# ============================================================

base_dir = '/ADD/PATH/TO/OUTPUT'

output_csv = os.path.join(base_dir, 'MeanFC_SEM_per_segment.csv')
output_png = os.path.join(base_dir, 'ALL_Tracts_FC_SEM.png')

# ============================================================
# Tract grouping
# ============================================================

cc_tracts = sorted([t for t in df['TractName'].unique() if t.startswith("CC")])
other_tracts = sorted([t for t in df['TractName'].unique() if not t.startswith("CC")])

# ============================================================
# Compute SEM stats
# ============================================================

def compute_stats(data, tract, hemi=""):

    stats = (
        data.groupby('Segment')[value_col]
        .agg(['mean', 'std', 'count'])
        .reset_index()
    )

    stats['SEM'] = stats['std'] / (stats['count'] ** 0.5)

    stats['TractName'] = tract
    stats['Hemi'] = hemi

    return stats

# ============================================================
# Build dataset
# ============================================================

all_stats = []

# CC tracts
for cc in cc_tracts:
    cc_data = df[df['TractName'] == cc]
    all_stats.append(compute_stats(cc_data, cc))

# Other tracts
for tract in other_tracts:

    tract_data = df[df['TractName'] == tract]

    for hemi in ['Left', 'Right']:

        hemi_data = tract_data[tract_data['Hemi'] == hemi]

        if hemi_data.empty:
            continue

        all_stats.append(compute_stats(hemi_data, tract, hemi))

# ============================================================
# Combine
# ============================================================

out = pd.concat(all_stats, ignore_index=True)

out = out.rename(columns={
    'mean': 'MeanFC',
    'std': 'StdFC'
})

out = out[
    ['TractName', 'Hemi', 'Segment', 'MeanFC', 'StdFC', 'SEM', 'count']
].sort_values(['TractName', 'Hemi', 'Segment'])

out.to_csv(output_csv, index=False)

print(f"Saved CSV: {output_csv}")

# ============================================================
# Plot styling
# ============================================================

hemi_colors = {
    "Left": "steelblue",
    "Right": "darkorange"
}

cc_colors = {
    "CC1": "red",
    "CC2": "green",
    "CC3": "blue",
    "CC4": "purple",
    "CC5": "orange",
    "CC6": "brown",
    "CC7": "pink"
}

def format_ax(ax):

    ax.set_xlabel("Segment", fontsize=8)
    ax.set_ylabel("Mean FC (log)", fontsize=8)

    ax.set_xticks(range(1, 21))
    ax.set_xlim(0.5, 20.5)

    ax.tick_params(axis='both', labelsize=7)

# ============================================================
# Plot helper
# ============================================================

def plot_sem(ax, d, color, label=None):

    ax.plot(
        d['Segment'],
        d['MeanFC'],
        linewidth=1.8,
        color=color,
        label=label
    )

    ax.errorbar(
        d['Segment'],
        d['MeanFC'],
        yerr=d['SEM'],
        fmt='D',
        markersize=2.5,
        markerfacecolor=color,
        markeredgecolor='black',
        color=color,
        ecolor=color,
        elinewidth=0.8,
        capsize=2,
        zorder=5
    )

# ============================================================
# SINGLE LARGE PNG
# ============================================================

all_panels = ['CC_COMBINED'] + other_tracts

ncols = 3
nrows = int(np.ceil(len(all_panels) / ncols))

fig, axes = plt.subplots(
    nrows,
    ncols,
    figsize=(18, 5 * nrows)
)

axes = np.array(axes).flatten()

# ============================================================
# Plot panels
# ============================================================

for idx, panel in enumerate(all_panels):

    ax = axes[idx]
        

    # =========================
    # PANEL LETTER (A, B, C...)
    # =========================
    label = chr(65 + idx) + ")"
    ax.text(
        -0.12, 1.05,
        label,
        transform=ax.transAxes,
        fontsize=12,
        fontweight='bold',
        va='top',
        ha='right'
    )

    # ---- rest of your plotting logic follows ----

    # --------------------------------------------------------
    # Combined CC panel
    # --------------------------------------------------------

    if panel == 'CC_COMBINED':

        for cc in cc_tracts:

            d = out[out['TractName'] == cc]

            plot_sem(
                ax,
                d,
                cc_colors.get(cc, 'black'),
                label=cc
            )

        ax.set_title("Corpus Callosum (CC1–CC7)", fontsize=10)
        ax.legend(fontsize=6)

    # --------------------------------------------------------
    # Other tracts
    # --------------------------------------------------------

    else:

        d = out[out['TractName'] == panel]

        for hemi in ['Left', 'Right']:

            dh = d[d['Hemi'] == hemi]

            if dh.empty:
                continue

            plot_sem(
                ax,
                dh,
                hemi_colors[hemi],
                label=hemi
            )

        ax.set_title(panel, fontsize=10)
        ax.legend(fontsize=6)

    format_ax(ax)

# ============================================================
# Remove unused axes
# ============================================================

for j in range(len(all_panels), len(axes)):
    fig.delaxes(axes[j])

# ============================================================
# Final formatting
# ============================================================

fig.suptitle(
    'Along-Tract Mean FC (log) ± SEM Profiles',
    fontsize=18,
    y=0.995
)

fig.tight_layout(rect=[0, 0, 1, 0.985])

# ============================================================
# Save PNG
# ============================================================

fig.savefig(
    output_png,
    dpi=600,
    bbox_inches='tight'
)

plt.close(fig)

print(f"Saved single PNG: {output_png}")