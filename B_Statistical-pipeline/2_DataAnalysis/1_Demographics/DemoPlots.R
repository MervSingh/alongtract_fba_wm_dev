rm(list =ls())

setwd("")
# Load packages
pkg = c("tidyverse", "broom", "dplyr", "readxl", "lubridate", "janitor")
lapply(pkg, require, character.only = TRUE)

# read My along-tract sample
dat = read_csv("demographics.csv")
str(dat)
dat = dat %>%
  mutate_at(c(1:4,6:7), as.factor) %>%
  mutate_at(c(5,8:9), as.numeric)

# --- Calculate how many session each subject has completed in my along-tract sample ---
unique_summary <- dat %>%
  dplyr::group_by(ID) %>%
  dplyr::summarise(
    n_sessions = dplyr::n(),
    Gender = first(Gender),
    first_age  = min(AgeAtScan, na.rm = TRUE),
    last_age   = max(AgeAtScan, na.rm = TRUE),
    .groups = "drop"
  )
write.csv(unique_summary,"unique_subjects_available_dwi.csv")

unique_summary %>%
  group_by(Gender, n_sessions) %>%
  summarise(count = n()) %>%
  print()


demo_table = dat %>%
  drop_na() %>%
  group_by(`Visit (mth)`) %>%
  summarise(count = n(),
            Male_n   = sum(Gender == "F", na.rm = TRUE),
            Female_n = sum(Gender == "M", na.rm = TRUE),
            right_n   = sum(Handedness_recoded == "1", na.rm = TRUE),
            left_n = sum(Handedness_recoded == "-1", na.rm = TRUE),
            amb_n   = sum(Handedness_recoded == "0", na.rm = TRUE),
            Age_mean = mean(AgeAtScan),
            Age_sd = sd(AgeAtScan),
            Age_min = min(AgeAtScan),
            Age_max = max(AgeAtScan),
            ICV_mean = mean(IntraCranialVol),
            ICV_sd = sd(IntraCranialVol),
            ICV_min = min(IntraCranialVol),
            ICV_max = max(IntraCranialVol),
            TDS_mean = mean(TDS),
            TDS_sd = sd(TDS),
            TDS_min = min(TDS),
            TDS_max = max(TDS))
write.csv(demo_table,"demo_table.csv")

# Barplots of how many sessions each subject has completed
p1 <- ggplot(unique_summary, aes(x = n_sessions, fill = Gender)) +
  geom_bar(position = "dodge") +
  labs(x = "Number of Sessions", y = "Count of Subjects", fill = "Gender") +
  theme_minimal() +
  ggtitle("Distribution of Sessions Completed by Subjects") +
  theme(plot.title = element_text(hjust = 0.5))
ggsave("./Sessions_per_subject.png", p1, width = 5,height=4)

# SAMPLE SPREAD OF SCORES
# order age variable and SID for plotting
ordered_dat <- dat %>% 
  mutate(AgeAtScan = round(as.numeric(AgeAtScan),2)) %>% 
  arrange(AgeAtScan) %>% 
  mutate(ID = factor(ID, unique(ID)))

# plot spread of data
p2 <- ggplot(ordered_dat, aes(y=ID, x=AgeAtScan, group=ID, colour=Gender)) +
  geom_line(size=.6,alpha=0.2) +
  ylab("Participants") +
  xlab("Age") +           
  geom_point(size=2, alpha=0.4) +
  theme_bw() +
  theme(axis.line = element_line(colour = "black"),
  axis.text.y = element_blank(),
  axis.ticks.y = element_blank(),
  legend.position="none",
  panel.grid.major = element_blank(),
  panel.grid.minor = element_blank(),
  panel.background = element_blank()) + 
  theme(legend.position="right") + 
  ggtitle('Total Sample')  +
  theme(plot.title = element_text(hjust = 0.5))  

# save
ggsave("./Study_spread.png", p2, width = 8,height=6)

# Histogram of age, TDS and ICV distribution

p3 <- ggplot(dat, aes(x=AgeAtScan, fill=Gender)) +
  geom_histogram(position="dodge", bins=10, alpha=0.7) +
  labs(x="Age at Scan", y="Count of Subjects  ", fill="Gender") +
  theme_minimal() +
  ggtitle("Distribution of Age at Scan") +
  theme(plot.title = element_text(hjust = 0.5))
ggsave("./Age_distribution.png", p3, width = 5,height=4)    

p3 <- ggplot(dat, aes(x=TDS, fill=Gender)) +
  geom_histogram(position="dodge", bins=10, alpha=0.7) +
  labs(x="TDS", y="Count of Subjects  ", fill="Gender") +
  theme_minimal() +
  ggtitle("Distribution of TDS") +
  theme(plot.title = element_text(hjust = 0.5))
ggsave("./TDS_distribution.png", p3, width = 5,height=4)   

p3 <- ggplot(dat, aes(x=IntraCranialVol, fill=Gender)) +
  geom_histogram(position="dodge", bins=10, alpha=0.7) +
  labs(x="IntraCranial Volume", y="Count of Subjects  ", fill="Gender") +
  theme_minimal() +
  ggtitle("Distribution of IntraCranial Volume") +
  theme(plot.title = element_text(hjust = 0.5))
ggsave("./ICV_distribution.png", p3, width = 5,height=4)   