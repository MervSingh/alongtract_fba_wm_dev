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
df <- read_csv("./Lin_Quad_Reduced/merged_output_parsed_combined_filtered.csv")

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
      numeric_vars <- setdiff(numeric_vars, "MeanFC")
      
      seg_data <- seg_data %>%
        group_by(TractName, Segment, Hemi) %>%
        mutate(across(all_of(numeric_vars),
                      ~ .x - mean(.x, na.rm = TRUE))) %>%
        ungroup()
      
      # =====================================================
      # LINEAR REDUCED MODEL
      # =====================================================
      model_linred <- lmer(
        MeanFC ~ AgeAtScan + Gender + IntraCranialVol + (1 | ID),
        data = seg_data,
        REML = FALSE
      )
      
      # =====================================================
      # QUADRATIC REDUCED MODEL
      # =====================================================
      model_quadred <- lmer(
        MeanFC ~ AgeAtScan + I(AgeAtScan^2) + Gender + IntraCranialVol + (1 | ID),
        data = seg_data,
        REML = FALSE
      )
      
      # =====================================================
      # STORE FIXED EFFECTS (optional future use)
      # =====================================================
      model_summaries[[paste(tract, hemi, seg, "linred", sep = "_")]] <-
        broom.mixed::tidy(model_linred, effects = "fixed") %>%
        mutate(Model = "Linear",
               Tract = tract,
               Hemisphere = hemi,
               Segment = seg)
      
      model_summaries[[paste(tract, hemi, seg, "quadred", sep = "_")]] <-
        broom.mixed::tidy(model_quadred, effects = "fixed") %>%
        mutate(Model = "Quadratic",
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
        AIC_Linear = AIC(model_linred),
        AIC_Quadratic = AIC(model_quadred),
        DeltaAIC = AIC(model_linred) - AIC(model_quadred)
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
  "./Lin_Quad_Reduced/AssocProj_ModelSummaries_LinRed_QuadRed_FC.csv"
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
          "./Lin_Quad_Reduced/LinQuad_DeltaAIC_AssocProj_FC.csv")

# =========================================================
# FIX SEGMENT SCALE (GLOBAL ACROSS ALL TRACTS)
# =========================================================

delta_df <- delta_df %>%
  mutate(
    Segment = as.factor(Segment),
    Hemisphere = factor(Hemisphere, levels = c("left", "right"))
  )
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
    name = expression(Delta*"AIC (Linear - Quadratic)")
  ) +
  
  facet_wrap(~Tract) +
  
  labs(
    title = "Comparisons between Linear and Quadratic (MeanFC models)",
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
  "./Lin_Quad_Reduced/LinQuad_DeltaAIC_Heatmap_AssocProj_FC.pdf",
  p_heat,
  width = 14,
  height = 6,
  device = cairo_pdf
)

cat("DONE: models + ΔAIC heatmap saved.\n")

# =========================================================
# FOREST PLOTS — AgeAtScan (Linear = inference model)
# Quadratic = sensitivity model
# =========================================================

pdf(
  "./Lin_Quad_Reduced/AgeAtScan_ForestPlots_LinRed_QuadRed_AssocProj_FC_.pdf",
  width = 18,
  height = 6,
  useDingbats = FALSE
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
      Model = factor(Model, levels = c("Linear", "Quadratic"))
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
        Model == "Linear" ~ Segment - 0.12,
        Model == "Quadratic"    ~ Segment + 0.12
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
      data = plot_df %>% filter(Model == "Linear"),
      aes(label = sig),
      hjust = -0.4,
      color = "black",
      size = 5,
      fontface = "bold",
      show.legend = FALSE
    ) +
    

    scale_linetype_manual(values = c(
      "Linear" = "solid",
      "Quadratic" = "dashed"
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
        hjust = 0.5,
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
# REDUCED MODEL ONLY
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
plot_lme_marginal_linquad_reduced_fc <- function(
    df,
    tract,
    hemi,
    seg,
    show_spaghetti = TRUE
) {

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

      Gender = factor(Gender),

      IntraCranialVol =
        scale(
          IntraCranialVol,
          center = TRUE,
          scale = FALSE
        )[,1],

    )

  if (nrow(seg_data) < 10) return(NULL)

  # -------------------------------------------------------
  # REDUCED MODEL
  # -------------------------------------------------------

  model_lin <- lmer(
    MeanFC ~ AgeAtScan +
      Gender +
      IntraCranialVol +
      (1 | ID),
    data = seg_data,
    REML = FALSE
  )

  # -------------------------------------------------------
  # QUADRATIC MODEL
  # -------------------------------------------------------

 model_quad <- lmer(
    MeanFC ~ AgeAtScan + I(AgeAtScan^2) +
      Gender +
      IntraCranialVol +
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

  newdata$AgeAtScan <-
    newdata$Age_raw -
    mean(seg_data$Age_raw, na.rm = TRUE)
  
  # marginalise ICV at mean
  newdata$IntraCranialVol <- 0

  # =======================================================
  # LINEAR PREDICTIONS
  # =======================================================

  X_lin <- model.matrix(
    ~ AgeAtScan + Gender + IntraCranialVol,
    newdata
  )

  beta_lin <- fixef(model_lin)

  newdata$fit_lin <- as.numeric(X_lin %*% beta_lin)

  vc_lin <- vcov(model_lin)

  se_lin <- sqrt(diag(X_lin %*% vc_lin %*% t(X_lin)))

  newdata$lower_lin <- newdata$fit_lin - 1.96 * se_lin
  newdata$upper_lin <- newdata$fit_lin + 1.96 * se_lin

  # =======================================================
  # QUADRATIC PREDICTIONS
  # =======================================================

  X_quad <- model.matrix(
    ~ AgeAtScan + I(AgeAtScan^2) + Gender + IntraCranialVol,
    newdata
  )

  beta_quad <- fixef(model_quad)

  newdata$fit_quad <- as.numeric(X_quad %*% beta_quad)

  vc_quad <- vcov(model_quad)

  se_quad <- sqrt(diag(X_quad %*% vc_quad %*% t(X_quad)))

  newdata$lower_quad <- newdata$fit_quad - 1.96 * se_quad
  newdata$upper_quad <- newdata$fit_quad + 1.96 * se_quad

  # -------------------------------------------------------
  # MARGINALISE OVER GENDER
  # -------------------------------------------------------

  pred_lin <- newdata %>%
    group_by(Age_raw) %>%
    summarise(
      fit = mean(fit_lin),
      lower = mean(lower_lin),
      upper = mean(upper_lin),
      .groups = "drop"
    ) %>%
    mutate(Model = "Linear")

  pred_quad <- newdata %>%
    group_by(Age_raw) %>%
    summarise(
      fit = mean(fit_quad),
      lower = mean(lower_quad),
      upper = mean(upper_quad),
      .groups = "drop"
    ) %>%
    mutate(Model = "Quadratic")

  pred_df <- bind_rows(pred_lin, pred_quad)

  # -------------------------------------------------------
  # MODEL STATS
  # -------------------------------------------------------
  lin_beta <- broom.mixed::tidy(
    model_lin,
    effects = "fixed"
  ) %>%
    filter(term == "AgeAtScan") %>%
    pull(estimate)
  
  lin_beta_p <- broom.mixed::tidy(
    model_lin,
    effects = "fixed"
  ) %>%
    filter(term == "AgeAtScan") %>%
    pull(p.value)

  lin_aic <- round(AIC(model_lin), 4)
  quad_aic <- round(AIC(model_quad), 4) 
  
  quad_beta_lin <- broom.mixed::tidy(
    model_quad,
    effects = "fixed"
  ) %>%
    filter(term == "AgeAtScan") %>%
    pull(estimate)
  
  quad_beta_lin_p <- broom.mixed::tidy(
    model_quad,
    effects = "fixed"
  ) %>%
    filter(term == "AgeAtScan") %>%
    pull(p.value)
  
  quad_beta_sq <- broom.mixed::tidy(
    model_quad,
    effects = "fixed"
  ) %>%
    filter(term == "I(AgeAtScan^2)") %>%
    pull(estimate)
  
  quad_beta_sq_p <- broom.mixed::tidy(
    model_quad,
    effects = "fixed"
  ) %>%
    filter(term == "I(AgeAtScan^2)") %>%
    pull(p.value)
  # -------------------------------------------------------
  # PLOT
  # -------------------------------------------------------

  p <- ggplot() +

    # CI ribbons
    geom_ribbon(
      data = pred_df,
      aes(
        x = Age_raw,
        ymin = lower,
        ymax = upper,
        fill = Model
      ),
      alpha = 0.18
    ) +

    # fitted lines
    geom_line(
      data = pred_df,
      aes(
        x = Age_raw,
        y = fit,
        color = Model,
        linetype = Model
      ),
      linewidth = 1.4
    ) +

    # observed points
    geom_point(
      data = seg_data,
      aes(
        x = Age_raw,
        y = MeanFC,
        color = Gender
      ),
      alpha = 0.6,
      size = 1.7
    ) +

    # spaghetti
    {
      if (show_spaghetti)
        geom_line(
          data = seg_data,
          aes(
            x = Age_raw,
            y = MeanFC,
            group = ID
          ),
          alpha = 0.12,
          color = "grey50"
        )
    } +

    annotate(
      "text",
      x = Inf,
      y = Inf,
      label = paste0(
        "Linear beta = ",
        round(lin_beta, 4),
        "\nLinear AIC = ",
        lin_aic,
        "\nLinear pval = ",
        round(lin_beta_p, 4),
        
        "\nQuadratic beta = ",
        
        round(quad_beta_sq, 4),
        "\nQuadratic AIC = ",
        quad_aic,
        "\nQuadratic pval = ",
        round(quad_beta_sq_p, 4)
        
      ),
      hjust = 1.1,
      vjust = 1.3,
      size = 4,
      fontface = "bold"
    )  +

    scale_color_manual(
      values = c(
        "Linear" = "#1f78b4",
        "Quadratic" = "#e31a1c",
        "F" = "purple",
        "M" = "gold"
      )
    ) +

    scale_fill_manual(
      values = c(
        "Linear" = "#1f78b4",
        "Quadratic" = "#e31a1c"
      )
    ) +

    scale_linetype_manual(
      values = c(
        "Linear" = "solid",
        "Quadratic" = "dashed"
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
      y = "Mean FC",
      color = NULL,
      fill = NULL,
      linetype = NULL
    ) +

    theme_minimal(base_size = 14) +

    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "bottom",
      panel.grid.minor = element_blank()
    )

# =======================================================
# SAVE INDIVIDUAL PNG
# =======================================================

out_dir <- "./Lin_Quad_Reduced/MarginalPlots_PNG"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

file_name <- paste0(
  tract, "_", hemi, "_seg-", seg, "FC.png"
)

ggsave(
  filename = file.path(out_dir, file_name),
  plot = p,
  width = 7,
  height = 5,
  dpi = 300,
  bg = "white"
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
      
      p <- plot_lme_marginal_linquad_reduced_fc(
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
# SAVE ALL PLOTS
# =========================================================

pdf(
  "./Lin_Quad_Reduced/MarginalPlots_LinQuad_ReducedModel_AssocProj_FC_v2.pdf",
  width = 11,
  height = 8.5,
  useDingbats = FALSE
)

for (nm in names(plot_list)) {
  print(plot_list[[nm]])
}

dev.off()

cat("DONE: marginal reduced-model linear-quadratic FC plots saved.\n")

# =========================================================
# SAVE PDF — 4x2 GRID (publication sized)
# =========================================================

library(patchwork)

plots_per_page <- 8

plot_chunks <- split(
  plot_list,
  ceiling(seq_along(plot_list) / plots_per_page)
)

pdf(
  "./Lin_Quad_Reduced/MarginalPlots_LinQuad_ReducedModel_AssocProj_FC_4x2.pdf",
  width = 12,
  height = 20,
  useDingbats = FALSE
)

for (chunk in plot_chunks) {
  
  combined_plot <- wrap_plots(
    chunk,
    ncol = 2,
    nrow = 4,
    guides = "collect"
  ) &
    
    theme(
      legend.position = "bottom",
      
      plot.title = element_text(size = 11),
      axis.title = element_text(size = 10),
      axis.text = element_text(size = 8),
      strip.text = element_text(size = 10),
      legend.title = element_text(size = 9),
      legend.text = element_text(size = 8)
    )
  
  print(combined_plot)
}

dev.off()

cat("DONE: 4x2 marginal plot PDF saved.\n")