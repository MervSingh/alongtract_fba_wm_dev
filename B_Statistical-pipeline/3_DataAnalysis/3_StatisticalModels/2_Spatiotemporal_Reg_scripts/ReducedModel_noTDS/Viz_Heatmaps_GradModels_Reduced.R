# =========================================================
# ALONG-TRACT HEATMAPS
# =========================================================

rm(list = ls())

# =========================================================
# LOAD LIBRARIES
# =========================================================

library(tidyverse)
library(openxlsx)
library(patchwork)

# =========================================================
# PATHS
# =========================================================

excel_path <- "~/PATH/TO/INPUT/HeatMap_Plot.xlsx"

out_dir <- "~/PATH/TO/OUTPUT/Heatmaps_Reduced"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# =========================================================
# LOAD + RESHAPE DATA
# =========================================================

df <- read.xlsx(excel_path)

df_long <- df %>%
  pivot_longer(
    cols = -c(Tract, Hemi),
    names_to = c("Measure", "Type"),
    names_pattern = "^(.*)_(estimate|pvalue)$",
    values_to = "Value"
  ) %>%
  pivot_wider(
    names_from = Type,
    values_from = Value
  ) %>%
  mutate(
    
    estimate = as.numeric(estimate),
    pvalue   = as.numeric(pvalue),
    
    Signif = case_when(
      pvalue < 0.001 ~ "***",
      pvalue < 0.01  ~ "**",
      pvalue < 0.05  ~ "*",
      TRUE ~ ""
    ),
    
    Hemi = factor(
      Hemi,
      levels = c("Left", "Right")
    ),
    
    Category = case_when(
      Tract %in% c(
        "SLF_I", "SLF_II", "SLF_III",
        "AF", "ILF", "IFO", "CG"
      ) ~ "Association",
      
      grepl("^CC", Tract) ~ "Commissural",
      
      TRUE ~ "Projection"
    )
  )

# =========================================================
# COLOR SCALE FUNCTION
# =========================================================

make_fill_scale <- function(gradient_type, tract_group = "Association") {
  
  low_col  <- "#313695"
  high_col <- "#a50026"
  
  guide_custom <- guide_colorbar(
    title.position = "top",
    title.hjust = 0.5,
    barwidth = 12,
    barheight = 0.8,
    label.position = "bottom",
    label.hjust = 0.5
  )
  
  if (gradient_type == "AP") {
    
    scale_fill_gradient2(
      low = low_col,
      mid = "white",
      high = high_col,
      midpoint = 0,
      limits = c(-1, 1),
      oob = scales::squish,
      breaks = c(-1, 0, 1),
      name = "P-A axis",
      labels = c(
        "-1\nFaster towards anterior",
        "0",
        "+1\nFaster towards posterior"
      ),
      guide = guide_custom
    )
  }
  
  else if (gradient_type == "DS" && tract_group == "Projection") {
    
    scale_fill_gradient2(
      low = low_col,
      mid = "white",
      high = high_col,
      midpoint = 0,
      limits = c(-1, 1),
      oob = scales::squish,
      breaks = c(-1, 0, 1),
      name = "I-S axis",
      labels = c(
        "-1\nFaster towards inferior",
        "0",
        "+1\nFaster towards superior"
      ),
      guide = guide_custom
    )
  }
  
  else if (gradient_type == "DS") {
    
    scale_fill_gradient2(
      low = low_col,
      mid = "white",
      high = high_col,
      midpoint = 0,
      limits = c(-1, 1),
      oob = scales::squish,
      breaks = c(-1, 0, 1),
      name = "D–S axis",
      labels = c(
        "-1\nFaster towards deep",
        "0",
        "+1\nFaster towards superficial"
      ),
      guide = guide_custom
    )
  }
  
  else if (gradient_type == "SA") {
    
    scale_fill_gradient2(
      low = low_col,
      mid = "white",
      high = high_col,
      midpoint = 0,
      limits = c(-1, 1),
      oob = scales::squish,
      breaks = c(-1, 0, 1),
      name = "S–A axis",
      labels = c(
        "-1\nFaster towards association",
        "0",
        "+1\nFaster towards sensorimotor"
      ),
      guide = guide_custom
    )
  }
  
  else {
    scale_fill_gradient2(
      low = low_col,
      mid = "white",
      high = high_col,
      midpoint = 0,
      limits = c(-1, 1),
      guide = guide_custom
    )
  }
}

# =========================================================
# BASE THEME
# =========================================================

base_theme <- theme_minimal(base_size = 18) +
  theme(
    
    panel.grid = element_blank(),
    
    axis.text.x = element_text(
      size = 16,
      face = "bold",
      color = "black"
    ),
    
    axis.text.y = element_text(
      size = 16,
      face = "bold",
      color = "black"
    ),
    
    strip.text = element_text(
      size = 16,
      face = "bold"
    ),
    
    plot.title = element_text(
      size = 20,
      face = "bold",
      hjust = 0.5
    ),
    
    legend.position = "bottom",
    
    legend.title = element_text(
      size = 16,
      face = "bold"
    ),
    
    legend.text = element_text(size = 13)
  )

# =========================================================
# GENERIC PLOT FUNCTION
# =========================================================

make_plot <- function(
    subdf,
    y_levels,
    gradient_type,
    plot_title,
    tract_group = "Association"
) {
  
  # -----------------------------------------
  # EMPTY CHECK
  # -----------------------------------------
  
  if (nrow(subdf) == 0) {
    
    warning(paste("No data:", plot_title))
    
    return(
      ggplot() +
        theme_void() +
        labs(title = plot_title)
    )
  }
  
  # -----------------------------------------
  # CLEAN
  # -----------------------------------------
  
  subdf <- subdf %>%
    mutate(
      
      Metric = case_when(
        grepl("^FD", Measure) ~ "FD",
        grepl("^FC", Measure) ~ "FC (log)",
        TRUE ~ NA_character_
      ),
      
      Hemisphere = case_when(
        Hemi == "Left"  ~ "Left",
        Hemi == "Right" ~ "Right",
        TRUE ~ NA_character_
      ),
      
      TextColor = ifelse(
        abs(estimate) >= 0.5,
        "white",
        "black"
      ),
      
      Label = paste0(
        sprintf("%.2f", estimate),
        Signif
      )
    ) %>%
    
    filter(
      !is.na(Metric),
      !is.na(estimate)
    )
  
  # -----------------------------------------
  # SECOND EMPTY CHECK
  # -----------------------------------------
  
  if (nrow(subdf) == 0) {
    
    warning(paste("No valid rows:", plot_title))
    
    return(
      ggplot() +
        theme_void() +
        labs(title = plot_title)
    )
  }
  
  # -----------------------------------------
  # FACTORS
  # -----------------------------------------
  
  subdf$Metric <- factor(
    subdf$Metric,
    levels = c("FD", "FC (log)")
  )
  
  subdf$Hemisphere <- factor(
    subdf$Hemisphere,
    levels = c("Left", "Right")
  )
  
  # -----------------------------------------
  # PLOT
  # -----------------------------------------
  
  ggplot(
    subdf,
    aes(
      x = Hemisphere,
      y = Tract,
      fill = estimate
    )
  ) +
    
    geom_tile(color = "white") +
    
    geom_text(
      aes(
        label = Label,
        color = TextColor
      ),
      size = 5,
      fontface = "bold"
    ) +
    
    scale_color_identity() +
    
    make_fill_scale(
      gradient_type,
      tract_group
    ) +
    
    scale_y_discrete(
      limits = rev(y_levels)
    ) +
    
    facet_grid(
      ~ Metric,
      scales = "free_x",
      space = "free_x",
      drop = FALSE
    ) +
    
    labs(
      x = NULL,
      y = "Tract",
      title = plot_title
    ) +
    
    base_theme
}

# =========================================================
# ASSOCIATION TRACTS
# =========================================================

df_assoc <- df_long %>%
  filter(Category == "Association")

assoc_order_AP <- c(
  "CG",
  "SLF_I",
  "SLF_II",
  "SLF_III"
)

assoc_order_DS <- c(
  "AF",
  "CG",
  "SLF_I",
  "SLF_II",
  "SLF_III"
)

# -------------------------
# AP
# -------------------------

plot_assoc_AP <- make_plot(
  subdf = df_assoc %>%
    filter(
      grepl("AP", Measure),
      Tract != "AF"
    ),
  
  y_levels = assoc_order_AP,
  
  gradient_type = "AP",
  
  plot_title = "Association tracts — Posterior-Anterior axis"
)

# -------------------------
# DS
# -------------------------

plot_assoc_DS <- make_plot(
  subdf = df_assoc %>%
    filter(
      grepl("DS", Measure),
      !Tract %in% c("IFO", "ILF")
    ),
  
  y_levels = assoc_order_DS,
  
  gradient_type = "DS",
  
  plot_title = "Association tracts — Deep–Superficial axis"
)

# -------------------------
# SA
# -------------------------

plot_assoc_SA <- make_plot(
  subdf = df_assoc %>%
    filter(
      grepl("AP", Measure),
      Tract %in% c("IFO", "ILF")
    ),
  
  y_levels = c("IFO", "ILF"),
  
  gradient_type = "SA",
  
  plot_title = "Association tracts — Sensorimotor–Association axis"
)

# -------------------------
# IFO + ILF DS
# -------------------------

plot_assoc_IFO_ILF_DS <- make_plot(
  subdf = df_assoc %>%
    filter(
      grepl("DS", Measure),
      Tract %in% c("IFO", "ILF")
    ),
  
  y_levels = c("IFO", "ILF"),
  
  gradient_type = "DS",
  
  plot_title = "Association tracts — Deep–Superficial axis"
)

# -------------------------
# COMBINED
# -------------------------

plot_assoc_combined <- plot_assoc_AP | plot_assoc_DS

plot_IFO_ILF_combined <- plot_assoc_SA | plot_assoc_IFO_ILF_DS

# =========================================================
# PROJECTION TRACTS
# =========================================================

plot_proj <- make_plot(
  
  subdf = df_long %>%
    filter(
      Category == "Projection",
      grepl("DS", Measure)
    ),
  
  y_levels = c(
    "CST",
    "FPT",
    "POPT"
  ),
  
  gradient_type = "DS",
  
  tract_group = "Projection",
  
  plot_title = "Projection tracts — Inferior-Superior axis"
)

# =========================================================
# COMMISSURAL TRACTS
# =========================================================

df_cc <- df_long %>%
  filter(Category == "Commissural")

if (nrow(df_cc) > 0) {
  
  df_cc <- df_cc %>%
    mutate(
      
      Metric = case_when(
        grepl("^FD", Measure) ~ "FD",
        grepl("^FC", Measure) ~ "FC (log)",
        TRUE ~ NA_character_
      ),
      
      TextColor = ifelse(
        abs(estimate) >= 0.5,
        "white",
        "black"
      ),
      
      Label = paste0(
        sprintf("%.2f", estimate),
        Signif
      )
    ) %>%
    
    filter(
      !is.na(Metric),
      !is.na(estimate)
    )
  
  df_cc$Metric <- factor(
    df_cc$Metric,
    levels = c("FD", "FC (log)")
  )
  
  plot_CC <- ggplot(
    df_cc,
    aes(
      x = Metric,
      y = Tract,
      fill = estimate
    )
  ) +
    
    geom_tile(color = "white") +
    
    geom_text(
      aes(
        label = Label,
        color = TextColor
      ),
      size = 5,
      fontface = "bold"
    ) +
    
    scale_color_identity() +
    
    make_fill_scale("DS") +
    
    facet_grid(
      ~ Metric,
      scales = "free_x",
      space = "free_x",
      drop = FALSE
    ) +
    
    labs(
      x = NULL,
      y = "Tract",
      title = "Commissural tracts — Deep–Superficial axis"
    ) +
    
    base_theme
  
} else {
  
  plot_CC <- ggplot() +
    theme_void() +
    labs(title = "No commissural data")
}

# =========================================================
# SAVE FIGURES
# =========================================================

ggsave(
  file.path(out_dir,
            "Association_Heatmap_AP_DS_Reduced.png"),
  plot_assoc_combined,
  width = 20,
  height = 10,
  dpi = 300
)

ggsave(
  file.path(out_dir,
            "Association_Heatmap_SA_Reduced.png"),
  plot_assoc_SA,
  width = 8,
  height = 6,
  dpi = 300
)

ggsave(
  file.path(out_dir,
            "Association_Heatmap_SA_DS_Reduced.png"),
  plot_IFO_ILF_combined,
  width = 15,
  height = 6,
  dpi = 300
)

ggsave(
  file.path(out_dir,
            "Projection_Heatmap_Reduced.png"),
  plot_proj,
  width = 8,
  height = 6,
  dpi = 300
)

ggsave(
  file.path(out_dir,
            "CC_Heatmap_Reduced.png"),
  plot_CC,
  width = 8,
  height = 6,
  dpi = 300
)

message("✅ Heatmaps saved to:\n", out_dir)