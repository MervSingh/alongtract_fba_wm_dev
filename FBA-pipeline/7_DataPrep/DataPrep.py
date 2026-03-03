import pandas as pd
import numpy as np

# Load summary files
df_fd = pd.read_csv('/Users/mervynsingh/Downloads/DataPrep/summary_fd_values.csv')
df_fc = pd.read_csv('/Users/mervynsingh/Downloads/DataPrep/summary_fc_values.csv')
df_demo = pd.read_csv('/Users/mervynsingh/Downloads/DataPrep/demographics.csv')  # Demographics file

# Clean columns and string values
for df in [df_fd, df_fc, df_demo]:
    df.columns = df.columns.str.strip()
    if 'Subject' in df.columns:
        df['Subject'] = df['Subject'].astype(str).str.strip()
    if 'Tract' in df.columns:
        df['Tract'] = df['Tract'].astype(str).str.strip()

# Merge FD and FC on Subject + Tract
df_summary = pd.merge(df_fd, df_fc, on=['Subject', 'Tract'], how='inner')

# Calculate FD retained percentage
if 'FD_RetainedFixels' in df_summary.columns and 'FD_TotalFixels' in df_summary.columns:
    df_summary['FD_Retained_Percent'] = (
        df_summary['FD_RetainedFixels'] / df_summary['FD_TotalFixels'] * 100
    ).round(2)
else:
    print("⚠️ Missing 'FD_RetainedFixels' or 'FD_TotalFixels' in FD summary.")

# Move FD_Retained_Percent just before MeanFC
if 'MeanFC' in df_summary.columns and 'FD_Retained_Percent' in df_summary.columns:
    cols = df_summary.columns.tolist()
    meanfc_index = cols.index('MeanFC')
    # Remove the new column and reinsert before MeanFC
    cols.insert(meanfc_index, cols.pop(cols.index('FD_Retained_Percent')))
    df_summary = df_summary[cols]

# Merge with demographics
df_merged = pd.merge(df_summary, df_demo, on='Subject', how='left')

# Save to CSV
df_merged.to_csv('/Users/mervynsingh/Downloads/DataPrep/merged_output.csv', index=False)
