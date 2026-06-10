# Clear workspace
rm(list = ls())

# Libraries
library(tidyverse)
library(dplyr)
library(lme4)
library(lmerTest)
library(broom.mixed)
library(RColorBrewer)
library(ggplot2)

# Working directory
setwd("/PATH/TO/INPUT")

# Load data
df <- read_csv("./LME/merged_output_parsed_combined_filtered.csv")

# Format data
df <- df %>% 
  dplyr::select(c(1:3,7,12,14:17,19:20,21)) %>%
  mutate_at(c(1:3,6:8,10), as.factor) %>% 
  mutate_at(c(4:5,9,11:12), as.numeric)
str(df)
# Remove corpus callosum
df <- df %>% filter(!grepl("^CC", TractName))

# =========================================================
# STORAGE
# =========================================================
model_summaries <- list()
delta_aic_store <- list()

# =========================================================
# LOOP: TRACTS
# =========================================================
for (tract in unique(df$TractName)) {
  
  tract_data <- df %>% filter(TractName == tract)
  
  for (hemi in c("left", "right")) {
    
    hemi_data <- tract_data %>% filter(Hemi == hemi)
    
    for (seg in unique(hemi_data$Segment)) {
      
      seg_data <- hemi_data %>% filter(Segment == seg)
      
      if (nrow(seg_data) < 10) next
      
      # -----------------------------
      # CENTERING
      # -----------------------------
      numeric_vars <- seg_data %>% select(where(is.numeric)) %>% names()
      numeric_vars <- setdiff(numeric_vars, "MeanFD")
      
      seg_data <- seg_data %>%
        group_by(TractName, Segment, Hemi) %>%
        mutate(across(all_of(numeric_vars),
                      ~ .x - mean(.x, na.rm = TRUE))) %>%
        ungroup()
      
      # =====================================================
      # REDUCED MODEL
      # =====================================================
      model_red <- lmer(
        MeanFD ~ AgeAtScan + Gender + (1 | ID),
        data = seg_data,
        REML = FALSE
      )
      
      # =====================================================
      # FULL MODEL
      # =====================================================
      model_full <- lmer(
        MeanFD ~ AgeAtScan + Gender +
          TDS + (1 | ID),
        data = seg_data,
        REML = FALSE
      )
      
      # =====================================================
      # STORE FIXED EFFECTS (optional future use)
      # =====================================================
      model_summaries[[paste(tract, hemi, seg, "red", sep = "_")]] <-
        broom.mixed::tidy(model_red, effects = "fixed") %>%
        mutate(Model = "Reduced",
               Tract = tract,
               Hemisphere = hemi,
               Segment = seg)
      
      model_summaries[[paste(tract, hemi, seg, "full", sep = "_")]] <-
        broom.mixed::tidy(model_full, effects = "fixed") %>%
        mutate(Model = "Full",
               Tract = tract,
               Hemisphere = hemi,
               Segment = seg)
      
      # =====================================================
      # ΔAIC (MAIN ANALYSIS)
      # =====================================================
      delta_aic_store[[paste(tract, hemi, seg, sep = "_")]] <- tibble(
        Tract = tract,
        Hemisphere = hemi,
        Segment = as.numeric(seg),
        AIC_Reduced = AIC(model_red),
        AIC_Full = AIC(model_full),
        DeltaAIC = AIC(model_red) - AIC(model_full)
      )
    }
  }
}

# =========================================================
# COMBINE RESULTS
# =========================================================
model_summaries_df <- bind_rows(model_summaries) %>%
  mutate(
    Segment = as.numeric(Segment),
    Hemisphere = factor(Hemisphere, levels = c("left", "right"))
  )
# =========================================================
# FDR CORRECTION FOR AgeAtScan
# Within each Tract × Hemisphere
# =========================================================

model_summaries_df <- model_summaries_df %>%
  mutate(p.adjusted = NA_real_) %>%
  
  group_by(Tract, Hemisphere, Model) %>%
  group_modify(~{
    
    df <- .x
    
    idx <- df$term == "AgeAtScan"
    
    df$p.adjusted[idx] <- p.adjust(df$p.value[idx], method = "fdr")
    
    df
  }) %>%
  
  ungroup() %>%
  
  mutate(
    sig = case_when(
      term == "AgeAtScan" & p.adjusted < 0.001 ~ "***",
      term == "AgeAtScan" & p.adjusted < 0.01  ~ "**",
      term == "AgeAtScan" & p.adjusted < 0.05  ~ "*",
      TRUE ~ ""
    )
  )
# =========================================================
# SAVE CSV OUTPUTS
# =========================================================
write_csv(
  model_summaries_df,
  "./LME/output/AssocProj_ModelSummaries_Reduced_Full_TDS_FD.csv"
)

# =========================================================
# COMBINE RESULTS
# =========================================================
delta_df <- bind_rows(delta_aic_store) %>%
  mutate(
    Segment = as.numeric(Segment),
    Hemisphere = factor(Hemisphere, levels = c("left", "right"))
  )

# =========================================================
# SAVE CSV
# =========================================================
write_csv(delta_df,
          "./LME/output/DeltaAIC_TDS_AssocProj_FD.csv")

# =========================================================
# HEATMAP
# =========================================================
p_heat <- ggplot(delta_df,
                 aes(x = Segment, y = Hemisphere, fill = DeltaAIC)) +
  
  geom_tile(color = "white", linewidth = 0.3) +
  
  scale_fill_gradient2(
    low = "blue",
    mid = "white",
    high = "red",
    midpoint = 0,
    name = expression(Delta*"AIC (Reduced - Full)")
  ) +
  
  facet_wrap(~Tract) +
  
  labs(
    title = "Comparisons between Full and Reduced (MeanFD models)",
    x = NULL,
    y = NULL
  ) +
  
  theme_minimal(base_size = 13) +
  
  theme(
    strip.text = element_text(face = "bold"),
    
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    
    axis.text.y = element_text(),
    axis.ticks.y = element_blank(),
    
    panel.grid = element_blank()
  )
# =========================================================
# SAVE HEATMAP
# =========================================================
ggsave(
  "./LME_Plots/DeltaAIC_TDS_Heatmap_AssocProj_FD.pdf",
  p_heat,
  width = 14,
  height = 6,
  device = cairo_pdf
)

cat("DONE: models + ΔAIC heatmap saved.\n")

# =========================================================
# FOREST PLOTS — AgeAtScan (Reduced = inference model)
# Full = sensitivity model
# =========================================================

pdf(
  "./LME_Plots/AgeAtScan_ForestPlots_Reduced_vs_Full_AssocProj_FD_TDS.pdf",
  width = 13,
  height = 5
)

for (tract in unique(model_summaries_df$Tract)) {
  
  plot_df <- model_summaries_df %>%
    filter(
      Tract == tract,
      term == "AgeAtScan"
    ) %>%
    mutate(
      Segment = as.numeric(Segment),
      Hemisphere = factor(Hemisphere, levels = c("left", "right")),
      Model = factor(Model, levels = c("Reduced", "Full"))
    )
  
  if (nrow(plot_df) == 0) next
  
  segs <- sort(unique(plot_df$Segment))
  
  segment_colors <- colorRampPalette(
    brewer.pal(min(9, max(3, length(segs))), "Spectral")
  )(length(segs))
  
  names(segment_colors) <- segs
  
  plot_df <- plot_df %>%
    mutate(
      SegmentPlot = case_when(
        Model == "Reduced" ~ Segment - 0.12,
        Model == "Full"    ~ Segment + 0.12
      )
    )
  
  forest_plot <- ggplot(plot_df,
                        aes(x = estimate,
                            y = SegmentPlot,
                            color = Model,
                            linetype = Model)) +
    
    geom_vline(xintercept = 0,
               linetype = "dashed",
               linewidth = 0.7) +
    
    geom_errorbarh(
      aes(
        xmin = estimate - 1.96 * std.error,
        xmax = estimate + 1.96 * std.error
      ),
      height = 0.12,
      linewidth = 0.9
    ) +
    
    geom_point(size = 3) +
    
    # =====================================================
    # SIGNIFICANCE STARS (Reduced model ONLY)
    # =====================================================
    
    geom_text(
      data = plot_df %>% filter(Model == "Reduced"),
      aes(label = sig),
      hjust = -0.4,
      color = "black",
      size = 5,
      fontface = "bold",
      show.legend = FALSE
    ) +
    

    scale_linetype_manual(values = c(
      "Reduced" = "solid",
      "Full" = "dashed"
    )) +
    
    scale_y_continuous(
      breaks = segs,
      labels = segs
    ) +
    
    facet_wrap(~Hemisphere, nrow = 1) +
    
    labs(
      title = paste("Forest Plot -", tract),
      x = "AgeAtScan Effect Estimate",
      y = "Segment",
      linetype = "Model"
    ) +
    
    theme_minimal(base_size = 14) +
    
    theme(
      plot.title = element_text(
        size = 18,
        face = "bold",
        hjust = 0.5
      ),
      axis.title = element_text(size = 16),
      axis.text = element_text(size = 13),
      strip.text = element_text(size = 16, face = "bold"),
      legend.position = "right",
      panel.grid.minor = element_blank()
    )
  
  print(forest_plot)
}

dev.off()

cat("DONE: Forest plots added.\n")

# =========================================================
# MARGINAL FIXED-EFFECTS PLOTS
# REDUCED MODEL ONLY (MeanFD)
# =========================================================

library(patchwork)

# ---------------------------------------------------------
# SETTINGS
# ---------------------------------------------------------

selected_tracts <- unique(df$TractName)

show_spaghetti <- TRUE

plot_list <- list()

# =========================================================
# FUNCTION
# =========================================================

plot_lme_marginal_reduced_fd <- function(df,
                                         tract,
                                         hemi,
                                         seg,
                                         show_spaghetti = TRUE) {
  
  # -------------------------------------------------------
  # SUBSET
  # -------------------------------------------------------
  
  seg_data <- df %>%
    filter(
      TractName == tract,
      Hemi == hemi,
      Segment == seg
    ) %>%
    mutate(
      Age_raw = AgeAtScan,
      
      # Match model pipeline
      AgeAtScan =
        AgeAtScan - mean(AgeAtScan, na.rm = TRUE),
      
      Gender = factor(Gender)
    )
  
  if (nrow(seg_data) < 10) return(NULL)
  
  # -------------------------------------------------------
  # REDUCED MODEL
  # -------------------------------------------------------
  
  model_red <- lmer(
    MeanFD ~ AgeAtScan +
      Gender +
      (1 | ID),
    data = seg_data,
    REML = FALSE
  )
  
  # -------------------------------------------------------
  # PREDICTION GRID
  # -------------------------------------------------------
  
  age_seq <- seq(
    min(seg_data$Age_raw, na.rm = TRUE),
    max(seg_data$Age_raw, na.rm = TRUE),
    length.out = 100
  )
  
  newdata <- expand.grid(
    Age_raw = age_seq,
    Gender = levels(seg_data$Gender)
  )
  
  # centered age
  newdata$AgeAtScan <-
    newdata$Age_raw -
    mean(seg_data$Age_raw, na.rm = TRUE)
  
  # -------------------------------------------------------
  # FIXED-EFFECTS PREDICTIONS
  # -------------------------------------------------------
  
  X <- model.matrix(
    ~ AgeAtScan + Gender,
    newdata
  )
  
  beta <- fixef(model_red)
  
  newdata$fit <- as.numeric(X %*% beta)
  
  vc <- vcov(model_red)
  
  se <- sqrt(diag(X %*% vc %*% t(X)))
  
  newdata$lower <- newdata$fit - 1.96 * se
  newdata$upper <- newdata$fit + 1.96 * se
  
  # -------------------------------------------------------
  # MARGINALISE OVER GENDER
  # -------------------------------------------------------
  
  newdata <- newdata %>%
    group_by(Age_raw) %>%
    summarise(
      fit = mean(fit),
      lower = mean(lower),
      upper = mean(upper),
      .groups = "drop"
    )
  
  # -------------------------------------------------------
  # AGE EFFECT
  # -------------------------------------------------------
  
  age_row <- broom.mixed::tidy(
    model_red,
    effects = "fixed"
  ) %>%
    filter(term == "AgeAtScan")
  
  beta_age <- round(age_row$estimate, 4)
  p_age <- signif(age_row$p.value, 3)
  
  # -------------------------------------------------------
  # PLOT
  # -------------------------------------------------------
  
  p <- ggplot() +
    
    geom_ribbon(
      data = newdata,
      aes(
        x = Age_raw,
        ymin = lower,
        ymax = upper
      ),
      alpha = 0.2
    ) +
    
    geom_line(
      data = newdata,
      aes(
        x = Age_raw,
        y = fit
      ),
      linewidth = 1.2
    ) +
    
    geom_point(
      data = seg_data,
      aes(
        x = Age_raw,
        y = MeanFD,
        color = Gender
      ),
      alpha = 0.65,
      size = 1.7
    ) +
    
    {
      if (show_spaghetti)
        geom_line(
          data = seg_data,
          aes(
            x = Age_raw,
            y = MeanFD,
            group = ID,
            color = Gender
          ),
          alpha = 0.15
        )
    } +
    
    annotate(
      "text",
      x = Inf,
      y = Inf,
      label = paste0(
        "\u03B2 = ",
        beta_age,
        "\n",
        "p = ",
        p_age
      ),
      hjust = 1.1,
      vjust = 1.5,
      size = 4.2,
      fontface = "bold"
    ) +
    
    scale_color_manual(
      values = c(
        "F" = "purple",
        "M" = "gold"
      )
    ) +
    
    labs(
      title = paste(
        tract,
        hemi,
        "Segment",
        seg
      ),
      x = "Age",
      y = "Mean FD",
      color = "Gender"
    ) +
    
    theme_minimal(base_size = 14) +
    
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "bottom",
      panel.grid.minor = element_blank()
    )
  
  return(p)
}

# =========================================================
# LOOP
# =========================================================

for (tract in selected_tracts) {
  
  tract_segments <- df %>%
    filter(TractName == tract) %>%
    pull(Segment) %>%
    unique() %>%
    sort()
  
  for (hemi in c("left", "right")) {
    
    for (seg in tract_segments) {
      
      p <- plot_lme_marginal_reduced_fd(
        df = df,
        tract = tract,
        hemi = hemi,
        seg = seg,
        show_spaghetti = show_spaghetti
      )
      
      if (!is.null(p)) {
        
        plot_list[[paste(
          tract,
          hemi,
          seg,
          sep = "_"
        )]] <- p
      }
    }
  }
}

# =========================================================
# SAVE PDF
# =========================================================

pdf(
  "./LME_Plots/MarginalPlots_ReducedModel_AssocProj_FD_v2.pdf",
  width = 11,
  height = 8.5,
  useDingbats = FALSE
)

for (nm in names(plot_list)) {
  print(plot_list[[nm]])
}

dev.off()

cat("DONE: marginal reduced-model FD plots saved.\n")