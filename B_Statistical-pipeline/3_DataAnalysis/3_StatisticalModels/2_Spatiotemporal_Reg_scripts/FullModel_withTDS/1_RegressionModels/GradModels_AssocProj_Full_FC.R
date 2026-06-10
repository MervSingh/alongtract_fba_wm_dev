# -----------------------------
# Libraries
# -----------------------------
library(dplyr)
library(tidyverse)
library(broom)
library(patchwork)
library(grid)
library(gridExtra)
library(purrr)  # for map_dfr

rm(list=ls())

# -----------------------------
# 1. Read and preprocess
# -----------------------------
# Load CSV with model results per segment, tract, and hemisphere
df <- read_csv("/PATH/TO/INPUT/AssocProj_ModelSummaries_Reduced_Full_TDS_FC.csv",
               col_types = cols(
                 .default = col_guess(),
                 p.adjusted = col_double(),
                 sig = col_character()
                 ))

df = df %>% filter(Model == "Full")
# Convert appropriate columns to factors and numeric
df <- df %>%
  mutate(across(c(1:2,8:10), as.factor)) %>%  # Tract, Hemisphere, etc.
  mutate(across(c(3:7,12:13), as.numeric))          # estimate, std.error, Segment, etc.
str(df)
# Keep only the term of interest
filtered_df <- df %>% filter(term == "AgeAtScan")

# -----------------------------
# 2. Segment filtering per tract
# -----------------------------
filter_segment_range <- function(data, tract) {
  # Apply tract-specific segment ranges
  if (tract %in% c("CST", "FPT", "POPT")) {
    data %>% filter(as.numeric(Segment) >= 1, as.numeric(Segment) <= 17)
  } else if (tract == "ILF") {
    data %>% filter(as.numeric(Segment) >= 4, as.numeric(Segment) <= 20)
  } else {
    data
  }
}

# -----------------------------
# 3. Hemisphere splitting
# -----------------------------
filtered_df_left <- filtered_df %>% filter(Hemisphere == "left")
filtered_df_right <- filtered_df %>% filter(Hemisphere == "right")

# -----------------------------
# 4. Segment processing & relabeling
# -----------------------------
process_segments <- function(df_hemi) {
  df_hemi %>%
    group_by(Tract) %>%
    group_split() %>%
    map_dfr(~ {
      df_seg <- filter_segment_range(.x, unique(.x$Tract))
      df_seg <- df_seg %>% mutate(Segment = as.numeric(Segment))
      
      if (unique(df_seg$Tract) %in% c("CST", "POPT", "FPT")) {
        # Projection tracts: one-sided labeling (deep → superficial)
        max_segment <- max(df_seg$Segment)
        df_seg <- df_seg %>%
          mutate(
            Segment_relabeled     = max_segment - Segment,
            Segment_relabeled_abs = max_segment - Segment,
            Relabel_Type          = "one-sided"
          )
      } else {
        # Association tracts: symmetrical relabeling (centered)
        df_seg <- df_seg %>%
          mutate(
            Segment_relabeled     = Segment - mean(Segment, na.rm = TRUE),
            Segment_relabeled_abs = abs(Segment_relabeled),
            Relabel_Type          = "symmetrical"
          )
      }
      df_seg
    })
}

# Apply to both hemispheres
filtered_df_left_segmented <- process_segments(filtered_df_left)
filtered_df_right_segmented <- process_segments(filtered_df_right)

# -----------------------------
# 5. Combine hemispheres
# -----------------------------
combined_segmented <- bind_rows(
  filtered_df_left_segmented %>% mutate(Hemisphere = "Left"),
  filtered_df_right_segmented %>% mutate(Hemisphere = "Right")
)

# Optional: save combined relabeled data
write_csv(
  combined_segmented,
  "/PATH/TO/OUTPUT/AssocProj_Relabeled_FC_full.csv"
)

# -----------------------------
# 6. Define tract groups
# -----------------------------
ap_ds_tracts <- c("AF", "SLF_I", "SLF_II", "SLF_III", "ILF", "IFO", "CG")  # Association
ds_tracts    <- c("CST", "FPT", "POPT")                                    # Projection

# -----------------------------
# 7. Fit raw models per tract & hemisphere
# -----------------------------
fit_group_models_raw <- function(data, group_tracts, group_label) {
  # Filter only tracts in the group
  df_group <- data %>% filter(Tract %in% group_tracts)
  
  # Define model formula
  formula <- if (group_label == "AP_DS") {
    # Association tracts: include both segment and segment_relabeled_abs
    estimate ~ Segment + Segment_relabeled_abs
  } else if (group_label == "SI") {
    # Projection tracts: only segment_relabeled_abs
    estimate ~ Segment_relabeled_abs
  } else {
    stop("Unknown group label")
  }
  
  # Fit linear model for each tract and hemisphere separately
  results <- df_group %>%
    group_by(Tract, Hemisphere) %>%
    do(tidy(lm(formula, data = .))) %>%
    ungroup() %>%
    mutate(Group = group_label)
  
  return(results)
}

# Fit raw models
ap_ds_raw <- fit_group_models_raw(combined_segmented, ap_ds_tracts, "AP_DS") %>%
  mutate(Tract_Group = "Association")
ds_raw    <- fit_group_models_raw(combined_segmented, ds_tracts, "SI") %>%
  mutate(Tract_Group = "Projection")

# Combine raw results
all_raw <- bind_rows(ap_ds_raw, ds_raw)

# -----------------------------
# 8. Post-hoc global standardization within each group
# -----------------------------
# Function to calculate standardized slopes using global SDs across all tracts in the group
posthoc_standardize <- function(raw_df, group_data) {
  sd_y <- sd(group_data$estimate, na.rm = TRUE)
  
  sd_x <- list(
    "Segment" = sd(group_data$Segment, na.rm = TRUE),
    "Segment_relabeled_abs" = if ("Segment_relabeled_abs" %in% names(group_data)) 
                                 sd(group_data$Segment_relabeled_abs, na.rm = TRUE) else NA
  )
  
  raw_df %>%
    rowwise() %>%
    mutate(
      estimate_std = case_when(
        term == "(Intercept)" ~ estimate / sd_y,
        term == "Segment" ~ estimate * (sd_x[["Segment"]] / sd_y),
        term == "Segment_relabeled_abs" ~ estimate * (sd_x[["Segment_relabeled_abs"]] / sd_y),
        TRUE ~ estimate
      )
    ) %>%
    ungroup()
}


# Standardize AP_DS group globally
ap_ds_std <- posthoc_standardize(ap_ds_raw, combined_segmented %>% filter(Tract %in% ap_ds_tracts))

# Standardize DS group globally
ds_std <- posthoc_standardize(ds_raw, combined_segmented %>% filter(Tract %in% ds_tracts))

# Combine all standardized results
all_std <- bind_rows(ap_ds_std, ds_std)

# -----------------------------
# 9. Save final standardized results
# -----------------------------
write_csv(
  all_std,
  "/PATH/TO/OUTPUT/AssocProj_GradModels_Results_FC_full.csv"
)
