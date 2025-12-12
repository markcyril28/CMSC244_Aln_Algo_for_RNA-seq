#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
csv_file <- args[1]
output_dir <- args[2]

library(ggplot2)
library(dplyr)
library(readr)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
data <- read_csv(csv_file, show_col_types = FALSE)

if(!"Command" %in% names(data)) quit(save = "no")

# Extract CPU count from command
data$CPU_Count <- sapply(data$Command, function(cmd) {
  cpu <- as.numeric(sub(".*(?:-p |--threads=|-@ )(\\d+).*", "\\1", cmd, perl=TRUE))
  if(is.na(cpu)) 1 else cpu
})

# Bin input sizes
data$Input_Bin <- cut(data$Input_Size_MB, breaks = 5)

# Runtime distribution by CPU
p1 <- ggplot(data, aes(x = factor(CPU_Count), y = User_Time_sec)) +
  geom_boxplot(fill = "#4CAF50") +
  labs(x = "CPU Count (cores)", y = "User Time Distribution (seconds)") +
  theme_minimal() +
  theme(plot.margin = unit(rep(1, 4), "inches"),
        panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(output_dir, "Runtime_Distribution_By_CPU.jpeg"),
       p1, width = 8, height = 6, dpi = 300, bg = "white")

