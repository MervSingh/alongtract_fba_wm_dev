setwd("/PATH/TO/INPUT")
rm(list=ls())
library(tidyverse)

dat_fd = read_csv("summary_fd_values.csv")
dat_fc = read_csv("summary_fc_values.csv")

dat_fd_sorted = dat_fd %>% arrange(Tract)
dat_fc_sorted = dat_fc %>% arrange(Tract)
all(dat_fd_sorted$Tract == dat_fc_sorted$Tract)

diff_df <- dat_fd_sorted %>%
  transmute(
    Tract,
    FD_FC_RetainedFixels = FD_RetainedFixels - dat_fc_sorted$FC_RetainedFixels
  )
write_csv(diff_df, "difference_fd_fc_retained_fixels.csv")
