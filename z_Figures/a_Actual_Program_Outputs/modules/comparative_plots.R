#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
base_dir <- args[1]
output_dir <- args[2]
programs <- strsplit(args[3], ",")[[1]]
input_size <- if(length(args) >= 4 && args[4] != "") as.numeric(args[4]) else NULL

library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

palette <- c("#FFFFFF", "#FFEB3B", "#CDDC39", "#8BC34A", "#4CAF50", 
             "#009688", "#00BCD4", "#3F51B5", "#673AB7", "#4A148C")

all_data <- data.frame()


for(prog in programs) {
  csv_file <- file.path(base_dir, prog, paste0(prog, ".csv"))
  df <- read_csv(csv_file, show_col_types = FALSE)
  df$Program <- prog
  all_data <- bind_rows(all_data, df)
}

if(nrow(all_data) == 0) quit(save = "no")

if(!is.null(input_size) && "Input_Size_MB" %in% names(all_data)) {
  all_data <- all_data %>% filter(Input_Size_MB == input_size)
}

if(nrow(all_data) == 0) quit(save = "no")

# Runtime_Comparison
if("User_Time_sec" %in% names(all_data)) {
  runtime_data <- all_data %>%
    group_by(Program) %>%
    summarise(Avg_Runtime = mean(User_Time_sec, na.rm = TRUE), .groups = "drop")
  
  p <- ggplot(runtime_data, aes(x = Program, y = Avg_Runtime, fill = Program)) +
    geom_bar(stat = "identity") +
    scale_fill_manual(values = palette) +
    labs(x = "Program", y = "Runtime (seconds)") +
    theme_minimal() +
    theme(plot.margin = unit(rep(1, 4), "inches"),
          panel.background = element_rect(fill = "white", color = NA),
          plot.background = element_rect(fill = "white", color = NA),
          axis.text.x = element_text(angle = 30, hjust = 1),
          legend.position = "none")
  ggsave(file.path(output_dir, "Runtime_Comparison.jpeg"), p, 
         width = 10, height = 6, dpi = 300, bg = "white")
}

# Memory_Comparison
if("Max_RSS_KB" %in% names(all_data)) {
  memory_data <- all_data %>%
    group_by(Program) %>%
    summarise(Avg_Memory = mean(Max_RSS_KB, na.rm = TRUE), .groups = "drop")
  
  p <- ggplot(memory_data, aes(x = Program, y = Avg_Memory, fill = Program)) +
    geom_bar(stat = "identity") +
    scale_fill_manual(values = palette) +
    labs(x = "Program", y = "Peak Memory (KB)") +
    theme_minimal() +
    theme(plot.margin = unit(rep(1, 4), "inches"),
          panel.background = element_rect(fill = "white", color = NA),
          plot.background = element_rect(fill = "white", color = NA),
          axis.text.x = element_text(angle = 30, hjust = 1),
          legend.position = "none")
  ggsave(file.path(output_dir, "Memory_Comparison.jpeg"), p, 
         width = 10, height = 6, dpi = 300, bg = "white")
}
