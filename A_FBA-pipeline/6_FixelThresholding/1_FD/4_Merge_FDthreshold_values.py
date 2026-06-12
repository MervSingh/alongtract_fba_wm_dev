import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages

# Base root directory where all tracts are located
base_dir = "/PATH/TO/DIRECTORY/template/segmentations"

# load highest second bin values from both analyses
second_bin_values_alltracts_path = os.path.join(base_dir, "highest_second_bin_values_other_tracts.csv")
second_bin_values_cc_path = os.path.join(base_dir, "highest_second_bin_values_cc.csv")  
# Save combined CSVs
combined_csv_path = os.path.join(base_dir, "highest_second_bin_values_fd_tracts.csv")
# Load data from both CSVs
df_alltracts = pd.read_csv(second_bin_values_alltracts_path)
df_cc = pd.read_csv(second_bin_values_cc_path)
# Combine the two DataFrames
combined_df = pd.concat([df_alltracts, df_cc], ignore_index=True)
# Save the combined DataFrame to a new CSV file
combined_df.to_csv(combined_csv_path, index=False)
print(f"\n✅ Combined highest second bin values saved to: {combined_csv_path}")