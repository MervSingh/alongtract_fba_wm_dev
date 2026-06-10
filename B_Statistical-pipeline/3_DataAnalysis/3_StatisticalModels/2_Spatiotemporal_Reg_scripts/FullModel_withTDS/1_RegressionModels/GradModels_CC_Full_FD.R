rm(list=ls())
library(tidyverse)
library(broom)
library(patchwork)
library(ggplot2)
library(grid)

# -----------------------------
# Read and preprocess
# -----------------------------
df <- read_csv("/PATH/TO/INPUT/CC_ModelSummaries_Reduced_Full_TDS_FD.csv",
               col_types = cols(
                 .default = col_guess(),
                 p.adjusted = col_double(),
                 sig = col_character()
               ))
df = df %>% filter(Model == "Full")
df <- df %>%
  mutate(across(c(1:2,8:10), as.factor)) %>%  # Tract, Hemisphere, etc.
  mutate(across(c(3:7,12), as.numeric))          # estimate, std.error, Segment, etc.
str(df)

filtered_df <- df %>% filter(term == "AgeAtScan")  # CC only

# -----------------------------
# Filter segment ranges
# -----------------------------
filter_segment_range <- function(data) {
  data %>% filter(as.numeric(Segment) >= 1, as.numeric(Segment) <= 20)
}

# -----------------------------
# Process segments per tract (global relabel)
# -----------------------------
filtered_df_segmented <- filtered_df %>%
  filter_segment_range() %>%
  group_by(Tract) %>%
  mutate(
    Segment = as.numeric(Segment),
    Segment_relabeled = Segment - mean(Segment, na.rm = TRUE),
    Segment_relabeled_abs = abs(Segment_relabeled)
  ) %>%
  ungroup()

# Optional: save relabeled combined data
write_csv(
  filtered_df_segmented,
  "/PATH/TO/OUTPUT/CC_Relabeled_Results_FD_full.csv"
)

# -----------------------------
# Fit CP-only model per tract (raw)
# -----------------------------
fit_cp_model <- function(data) {
  model <- lm(estimate ~ Segment_relabeled_abs, data = data)
  broom::tidy(model)
}

cc_tracts <- paste0("CC", 1:7)

cc_results_list <- map(cc_tracts, function(tract) {
  data_tract <- filtered_df_segmented %>% filter(Tract == tract)
  tidied <- fit_cp_model(data_tract)
  tidied$Tract <- tract
  tidied
})

combined_CC <- bind_rows(cc_results_list)

# -----------------------------
# Compute global SDs for standardization
# -----------------------------
global_sd_y <- sd(filtered_df_segmented$estimate, na.rm = TRUE)
global_sd_x <- sd(filtered_df_segmented$Segment_relabeled_abs, na.rm = TRUE)

# -----------------------------
# Standardize slopes globally
# -----------------------------
combined_CC <- combined_CC %>%
  mutate(
    estimate_std = case_when(
      term == "Segment_relabeled_abs" ~ estimate * (global_sd_x / global_sd_y),
      TRUE ~ estimate
    )
  )

# -----------------------------
# Save full results (raw + globally standardized)
# -----------------------------
write_csv(
  combined_CC,
  "/PATH/TO/OUTPUT/CC_GradModels_Results_FD_full.csv"
)
  