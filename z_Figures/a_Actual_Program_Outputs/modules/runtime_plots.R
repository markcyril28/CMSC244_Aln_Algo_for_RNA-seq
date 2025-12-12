#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
csv_file <- args[1]
output_dir <- args[2]

library(ggplot2)
library(dplyr)
library(readr)

data <- read_csv(csv_file, show_col_types = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

palette <- c("#FFFFFF", "#FFEB3B", "#CDDC39", "#8BC34A", "#4CAF50", 
             "#009688", "#00BCD4", "#3F51B5", "#673AB7", "#4A148C")



# CPU Count vs Avg User Time
if(all(c("Command", "User_Time_sec") %in% names(data))) {
  data$CPU_Count <- sapply(data$Command, function(cmd) {
    if(grepl("-p\\s+\\d+", cmd, perl=TRUE)) {
      cpu <- as.numeric(sub(".*-p\\s+(\\d+).*", "\\1", cmd, perl=TRUE))
    } else if(grepl("--threads=\\d+", cmd, perl=TRUE)) {
      cpu <- as.numeric(sub(".*--threads=(\\d+).*", "\\1", cmd, perl=TRUE))
    } else if(grepl("--num-threads\\s+\\d+", cmd, perl=TRUE)) {
      cpu <- as.numeric(sub(".*--num-threads\\s+(\\d+).*", "\\1", cmd, perl=TRUE))
    } else if(grepl("-@\\s+\\d+", cmd, perl=TRUE)) {
      cpu <- as.numeric(sub(".*-@\\s+(\\d+).*", "\\1", cmd, perl=TRUE))
    } else {
      cpu <- NA
    }
    if(is.na(cpu)) 1 else cpu
  })
  cpu_data <- data %>%
    filter(!is.na(CPU_Count) & CPU_Count > 1) %>%
    group_by(CPU_Count) %>%
    summarise(Avg_User_Time = mean(User_Time_sec, na.rm = TRUE), .groups = "drop")
  
  if(nrow(cpu_data) > 0) {
    max_cpu <- max(cpu_data$CPU_Count, na.rm = TRUE)
    x_breaks <- seq(8, ceiling(max_cpu / 8) * 8, by = 8)
    p <- ggplot(cpu_data, aes(x = CPU_Count, y = Avg_User_Time)) +
      geom_point(size = 3, color = palette[7]) +
      geom_line(color = palette[7]) +
      scale_x_continuous(breaks = x_breaks) +
      labs(x = "CPU Count (cores)", y = "Average User Time (seconds)") +
      theme_minimal() +
      theme(plot.margin = unit(rep(1, 4), "inches"),
            panel.background = element_rect(fill = "white", color = NA),
            plot.background = element_rect(fill = "white", color = NA))
    ggsave(file.path(output_dir, "CPU_Count_vs_Avg_User_Time_sec.jpeg"),
           p, width = 8, height = 6, dpi = 300, bg = "white")
  }
}

