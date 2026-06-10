# =========================================================
# BONFERRONI CORRECTION — ASSOCIATION TRACTS
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
  "AssocProj_GradModels_Results_FD.csv"
)

fc_input <- file.path(
  base_dir,
  "AssocProj_GradModels_Results_FC.csv"
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
      Tract_Group == "Association",
      term == "Segment"
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

assoc_fd_ap <- apply_bonferroni(fd_input)

write_csv(
  assoc_fd_ap,
  file.path(
    output_dir,
    "Bonferroni_By_TractGroup_Assoc_AP_FD_Reduced.csv"
  )
)

# =========================================================
# PROCESS FC RESULTS
# =========================================================

assoc_fc_ap <- apply_bonferroni(fc_input)

write_csv(
  assoc_fc_ap,
  file.path(
    output_dir,
    "Bonferroni_By_TractGroup_Assoc_AP_FC_Reduced.csv"
  )
)

# =========================================================
# DONE
# =========================================================

cat("Bonferroni correction completed successfully.\n")