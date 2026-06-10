# =========================================================
# BONFERRONI CORRECTION — CC TRACTS
# =========================================================

rm(list = ls())

# =========================================================
# LOAD LIBRARIES
# =========================================================

library(tidyverse)

# =========================================================
# DEFINE PATHS
# =========================================================

base_dir <- "/PATH/TO/INPUT"

fd_input <- file.path(
  base_dir,
  "CC_GradModels_Results_FD.csv"
)

fc_input <- file.path(
  base_dir,
  "CC_GradModels_Results_FC.csv"
)

output_dir <- file.path(
  base_dir
)

# Create output directory if needed
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# =========================================================
# FUNCTION: APPLY BONFERRONI CORRECTION
# =========================================================

apply_bonferroni <- function(input_file) {
  
  read_csv(input_file, show_col_types = FALSE) %>%
    filter(
      term == "Segment_relabeled_abs"
    ) %>%
    mutate(
      n_tests      = n(),
      p_adj_bonf   = p.adjust(p.value, method = "bonferroni"),
      Significant  = p_adj_bonf < 0.05
    )
}

# =========================================================
# PROCESS FD RESULTS
# =========================================================

cc_fd_ds <- apply_bonferroni(fd_input)

write_csv(
  cc_fd_ds,
  file.path(
    output_dir,
    "Bonferroni_By_TractGroup_CC_DS_FD_Reduced.csv"
  )
)

# =========================================================
# PROCESS FC RESULTS
# =========================================================

cc_fc_ds <- apply_bonferroni(fc_input)

write_csv(
  cc_fc_ds,
  file.path(
    output_dir,
    "Bonferroni_By_TractGroup_CC_DS_FC_Reduced.csv"
  )
)

# =========================================================
# DONE
# =========================================================

cat("Bonferroni correction completed successfully.\n")