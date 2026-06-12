#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Sequential QC filtering + full audit + visual QC reporting

Pre-QC exclusions (NOT counted in QC):
    1. FX (fornix) rows
    2. Missing ICV rows

Sequential QC:
    1. CST/POPT/FPT segments 18–20
    2. ILF segments 1–3
    3. FD retained < 75%
"""

import pandas as pd
import re
import matplotlib.pyplot as plt

# =========================================================
# LOAD DATA
# =========================================================

input_file = (
    '/PATH/TO/INPUT/'
    'merged_output.csv'
)

df = pd.read_csv(input_file)

# =========================================================
# REMOVE UNWANTED COLUMNS
# =========================================================

columns_to_remove = [
    'IntraCranialVol_notes',
    'Unnamed: 10'
]

df = df.drop(
    columns=[
        col for col in columns_to_remove
        if col in df.columns
    ]
)

# =========================================================
# FUNCTION TO PARSE TRACT NAMES
# =========================================================

def split_tract_name(name):

    name = str(name)

    # -----------------------------------------------------
    # Corpus Callosum
    # -----------------------------------------------------
    if name.startswith('CC_'):

        match = re.match(r'CC_(\d+)_(\d+)', name)

        if match:

            tract_num = match.group(1)
            segment = match.group(2)

            return (
                f'CC{tract_num}',
                'CC',
                segment,
                'CC'
            )

    # -----------------------------------------------------
    # Non-CC tracts
    # -----------------------------------------------------
    match = re.match(
        r'(?P<Tract>[A-Z]+(?:_[A-Z]+)?)_(?P<Hemi>left|right)?_?(?P<Segment>\d+)?',
        name
    )

    if match:

        return (
            match.group('Tract'),
            match.group('Hemi'),
            match.group('Segment'),
            'Non-CC'
        )

    return None, None, None, 'Unknown'

# =========================================================
# APPLY TRACT PARSING
# =========================================================

df[['TractName', 'Hemi', 'Segment', 'TractType']] = (
    df['Tract']
    .apply(lambda x: pd.Series(split_tract_name(x)))
)

# =========================================================
# REORDER COLUMNS
# =========================================================

df = df[
    ['TractName', 'Hemi', 'Segment', 'TractType'] +
    [
        col for col in df.columns
        if col not in [
            'TractName',
            'Hemi',
            'Segment',
            'TractType'
        ]
    ]
]

# =========================================================
# REMOVE FORNIX FIRST (NOT COUNTED IN QC)
# =========================================================

fx_mask = (
    (df['TractName'] == 'FX') &
    (df['Hemi'].isin(['left', 'right']))
)

n_fx_removed = fx_mask.sum()

df = df[~fx_mask]

print(f"🟢 Removed {n_fx_removed} FX rows prior to QC")

# =========================================================
# REMOVE MISSING ICV (NOT COUNTED IN QC)
# =========================================================

icv_mask = df['IntraCranialVol'].isna()

n_icv_removed = icv_mask.sum()

df = df[~icv_mask]

print(
    f"🟢 Removed {n_icv_removed} rows with missing ICV prior to QC"
)

# =========================================================
# SAVE PRE-QC DATASET
# =========================================================

unfiltered_output = (
    '/PATH/TO/OUTPUT/'
    'merged_output_parsed_combined.csv'
)

df.to_csv(unfiltered_output, index=False)

print(
    f"🟢 Pre-QC parsed data saved to: {unfiltered_output}"
)

# =========================================================
# SEQUENTIAL QC FILTERING
# =========================================================

df_work = df.copy()

removed_all = []

# =========================================================
# 1. CST / POPT / FPT SEGMENTS 18–20
# =========================================================

mask1 = (
    df_work['TractName'].isin(
        ['CST', 'POPT', 'FPT']
    )
    &
    df_work['Segment'].isin(
        ['18', '19', '20']
    )
)

removed_all.append(
    df_work[mask1].assign(
        RemovalStage='CST_POPT_FPT_seg_18_20'
    )
)

df_work = df_work[~mask1]

# =========================================================
# 2. ILF SEGMENTS 1–3
# =========================================================

mask2 = (
    (df_work['TractName'] == 'ILF')
    &
    (df_work['Segment'].isin(
        ['1', '2', '3']
    ))
)

removed_all.append(
    df_work[mask2].assign(
        RemovalStage='ILF_seg_1_3'
    )
)

df_work = df_work[~mask2]

# =========================================================
# 3. FD RETAINED < 75%
# =========================================================

mask3 = (
    df_work['FD_Retained_Percent'] < 75
)

removed_all.append(
    df_work[mask3].assign(
        RemovalStage='FD_retained_below_75'
    )
)

df_work = df_work[~mask3]

# =========================================================
# FINAL DATASETS
# =========================================================

df_filtered = df_work.copy()

df_removed = pd.concat(
    removed_all,
    ignore_index=True
)

# =========================================================
# QC SUMMARY
# =========================================================

total_entering_qc = len(df)

total_removed = len(df_removed)

total_retained = len(df_filtered)

qc_summary = pd.DataFrame({

    'Metric': [
        'FX rows excluded before QC',
        'Missing ICV rows excluded before QC',
        'Total rows entering QC',
        'Total removed during QC',
        'Total retained rows',
        'Removal rate during QC (%)'
    ],

    'Value': [
        n_fx_removed,
        n_icv_removed,
        total_entering_qc,
        total_removed,
        total_retained,
        round(
            (total_removed / total_entering_qc) * 100,
            2
        )
    ]
})

# =========================================================
# SAVE QC SUMMARY
# =========================================================

qc_summary_path = (
    '/PATH/TO/OUTPUT/'
    'QC_summary_overall.csv'
)

qc_summary.to_csv(
    qc_summary_path,
    index=False
)

print("\n")
print(qc_summary)
print("\n")

# =========================================================
# FULL REMOVED CASE AUDIT TABLE
# =========================================================

audit_columns = [
    c for c in [
        'Subject',
        'ID',
        'TractName',
        'Hemi',
        'Segment',
        'RemovalStage'
    ]
    if c in df_removed.columns
]

df_removed_audit = (
    df_removed[audit_columns]
)

sort_columns = [
    c for c in [
        'TractName',
        'Hemi',
        'Segment'
    ]
    if c in df_removed_audit.columns
]

df_removed_audit = (
    df_removed_audit
    .sort_values(by=sort_columns)
)

audit_output = (
    '/PATH/TO/OUTPUT/'
    'QC_removed_cases_full_list.csv'
)

df_removed_audit.to_csv(
    audit_output,
    index=False
)

# =========================================================
# REMOVAL COUNTS BY STAGE
# =========================================================

stage_order = [
    'CST_POPT_FPT_seg_18_20',
    'ILF_seg_1_3',
    'FD_retained_below_75'
]

stage_counts = (
    df_removed['RemovalStage']
    .value_counts()
    .reindex(stage_order, fill_value=0)
)

# =========================================================
# BARPLOT
# =========================================================

plt.figure(figsize=(10, 6))

stage_counts.plot(kind='bar')

plt.ylabel('Number of Removed Rows')

plt.xlabel('Removal Stage')

plt.title(
    'QC Removal Summary by Stage (Sequential Order)'
)

plt.xticks(
    rotation=45,
    ha='right'
)

plt.tight_layout()

plot_output = (
    '/PATH/TO/OUTPUT/'
    'QC_removed_by_stage.png'
)

plt.savefig(
    plot_output,
    dpi=300
)

plt.close()

# =========================================================
# SAVE FINAL DATASETS
# =========================================================

filtered_output = (
    '/PATH/TO/OUTPUT/'
    'merged_output_parsed_combined_filtered.csv'
)

removed_output = (
    '/PATH/TO/OUTPUT/'
    'merged_output_removed_ROWS.csv'
)

df_filtered.to_csv(
    filtered_output,
    index=False
)

df_removed.to_csv(
    removed_output,
    index=False
)

# =========================================================
# FINAL MESSAGE
# =========================================================

print("✅ QC pipeline complete")
print(
    f"🟢 Filtered data saved to: {filtered_output}"
)
print(
    f"🟢 Removed rows saved to: {removed_output}"
)
print(
    f"🟢 QC summary saved to: {qc_summary_path}"
)
print(
    f"🟢 Audit table saved to: {audit_output}"
)
print(
    f"🟢 QC plot saved to: {plot_output}"
)