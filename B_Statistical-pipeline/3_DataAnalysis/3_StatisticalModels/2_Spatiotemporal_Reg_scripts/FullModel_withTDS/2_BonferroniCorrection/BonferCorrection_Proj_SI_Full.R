# =========================================================
# BONFERRONI CORRECTION — PROJECTION TRACTS
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
  "AssocProj_GradModels_Results_FD_Full.csv"
)

fc_input <- file.path(
  base_dir,
  "AssocProj_GradModels_Results_FC_Full.csv"
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
      Tract_Group == "Projection",
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

proj_fd_si <- apply_bonferroni(fd_input)

write_csv(
  proj_fd_si,
  file.path(
    output_dir,
    "Bonferroni_By_TractGroup_Proj_SI_FD_Full.csv"
  )
)

# =========================================================
# PROCESS FC RESULTS
# =========================================================

proj_fc_si <- apply_bonferroni(fc_input)

write_csv(
  proj_fc_si,
  file.path(
    output_dir,
    "Bonferroni_By_TractGroup_Proj_SI_FC_Full.csv"
  )
)

# =========================================================
# DONE
# =========================================================

cat("Bonferroni correction completed successfully.\n")