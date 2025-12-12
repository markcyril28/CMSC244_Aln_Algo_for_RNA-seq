#!/usr/bin/env Rscript
# Combined/Comparative Analysis: Runtime Complexity and Memory Usage
# Generates grouped bar charts for HISAT2, Bowtie2/RSEM, and Salmon comparison

args <- commandArgs(trailingOnly = TRUE)
base_dir <- if(length(args) >= 1) args[1] else "."
output_dir <- if(length(args) >= 2) args[2] else file.path(base_dir, "Comparative_Analysis")

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(gridExtra)
  library(grid)
})

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Tool groupings and file mappings
tool_config <- list(
  "hisat2-build" = list(group = "HISAT2", file = "hisat2-build/hisat2-build.csv"),
  "hisat2" = list(group = "HISAT2", file = "hisat2/hisat2.csv"),
  "rsem-prepare-reference" = list(group = "Bowtie2", file = "rsem-prepare-reference/rsem-prepare-reference.csv"),
  "rsem-calculate-expression" = list(group = "Bowtie2", file = "rsem-calculate-expression/rsem-calculate-expression.csv"),
  "salmon_index" = list(group = "Salmon", file = "salmon_index/salmon_index.csv"),
  "salmon_quant" = list(group = "Salmon", file = "salmon_quant/salmon_quant.csv")
)

group_colors <- c("HISAT2" = "#2980b9", "Bowtie2" = "#c0392b", "Salmon" = "#27ae60")
tool_fills <- c(
  "hisat2-build" = "#3498db", "hisat2" = "#2980b9",
  "rsem-prepare-reference" = "#e74c3c", "rsem-calculate-expression" = "#c0392b",
  "salmon_index" = "#2ecc71", "salmon_quant" = "#27ae60"
)

extract_cpu_count <- function(cmd) {
  if(is.na(cmd) || cmd == "") return(NA)
  match <- regmatches(cmd, regexpr("(?:-p |--num-threads |--threads=|-@ )(\\d+)", cmd, perl = TRUE))
  if(length(match) > 0) as.numeric(gsub("[^0-9]", "", match)) else NA
}

col_names <- c("Timestamp", "Command", "Elapsed_Time_sec", "CPU_Percent", 
               "Max_RSS_KB", "User_Time_sec", "System_Time_sec", 
               "Input_Size_MB", "Output_Size_MB", "Exit_Status")

load_tool_data <- function(base_dir, tool_config) {
  all_data <- data.frame()
  for(tool in names(tool_config)) {
    csv_path <- file.path(base_dir, "per_command_from_space_time_logs", tool_config[[tool]]$file)
    if(file.exists(csv_path)) {
      # Check if file has header
      first_line <- tryCatch(readLines(csv_path, n = 1), error = function(e) "")
      has_header <- grepl("^Timestamp", first_line)
      
      df <- tryCatch({
        if(has_header) {
          read_csv(csv_path, show_col_types = FALSE)
        } else {
          read_csv(csv_path, col_names = col_names, show_col_types = FALSE)
        }
      }, error = function(e) NULL)
      
      if(!is.null(df) && nrow(df) > 0 && "Command" %in% names(df)) {
        # Filter to only include rows matching the tool (handle underscore vs space)
        tool_pattern <- gsub("_", " ", tool)
        df <- df %>% filter(grepl(tool_pattern, Command, fixed = TRUE))
        if(nrow(df) > 0) {
          df$Tool <- tool
          df$Group <- tool_config[[tool]]$group
          df$CPU_Count <- as.numeric(unlist(lapply(df$Command, extract_cpu_count)))
          all_data <- bind_rows(all_data, df)
        }
      }
    }
  }
  if(nrow(all_data) == 0) return(all_data)
  all_data %>% filter(Exit_Status == 0, User_Time_sec > 0)
}

# Load all data
all_data <- load_tool_data(base_dir, tool_config)
if(nrow(all_data) == 0) { cat("No data found.\n"); quit(save = "no") }

# Define tool order for consistent plotting
tool_order <- c("hisat2-build", "hisat2", "rsem-prepare-reference", 
                "rsem-calculate-expression", "salmon_index", "salmon_quant")
all_data$Tool <- factor(all_data$Tool, levels = tool_order)
all_data$Group <- factor(all_data$Group, levels = c("HISAT2", "Bowtie2", "Salmon"))

# Runtime Complexity Plot
runtime_data <- all_data %>%
  group_by(Tool, Group) %>%
  summarise(Avg_User_Time = mean(User_Time_sec, na.rm = TRUE), .groups = "drop")

p_runtime <- ggplot(runtime_data, aes(x = Tool, y = Avg_User_Time, fill = Tool)) +
  geom_bar(stat = "identity", color = "black", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.1fs", Avg_User_Time)), vjust = -0.3, size = 3) +
  scale_fill_manual(values = tool_fills) +
  scale_y_log10(labels = scales::comma) +
  facet_grid(. ~ Group, scales = "free_x", space = "free_x") +
  labs(x = NULL, y = "Average User Time (seconds)", 
       title = "Runtime Complexity Comparison",
       subtitle = "HISAT2 vs Bowtie2/RSEM vs Salmon") +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
    strip.text = element_text(face = "bold", size = 11),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(file.path(output_dir, "Runtime_Complexity_Comparison.jpeg"), p_runtime,
       width = 12, height = 7, dpi = 300, bg = "white")

# CPU Count vs Average User Time (Line Graph) - Main Operations Only
main_tools <- c("hisat2", "rsem-calculate-expression", "salmon_quant")

create_cpu_vs_time_plot <- function(data, tools) {
  plot_data <- data %>%
    filter(Tool %in% tools, !is.na(CPU_Count)) %>%
    group_by(Tool, Group, CPU_Count) %>%
    summarise(Avg_User_Time = mean(User_Time_sec, na.rm = TRUE), .groups = "drop")
  
  if(nrow(plot_data) == 0) return(NULL)
  
  ggplot(plot_data, aes(x = CPU_Count, y = Avg_User_Time, color = Tool, group = Tool)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    scale_color_manual(values = tool_fills) +
    scale_x_continuous(breaks = seq(0, max(plot_data$CPU_Count, na.rm = TRUE), by = 16)) +
    labs(x = "CPU Count", y = "Average User Time (seconds)",
         title = "CPU Count vs Average User Time",
         subtitle = "HISAT2 vs Bowtie2/RSEM vs Salmon") +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5),
      legend.position = "bottom",
      legend.title = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA)
    )
}

p_cpu_time <- create_cpu_vs_time_plot(all_data, main_tools)
if(!is.null(p_cpu_time)) {
  ggsave(file.path(output_dir, "Combined_CPU_Count_vs_Avg_User_Time_sec.jpeg"), p_cpu_time,
         width = 12, height = 7, dpi = 300, bg = "white")
}

# Memory Usage at CPU32 and CPU64
create_memory_plot <- function(data, cpu_val, title_suffix) {
  mem_data <- data %>%
    filter(CPU_Count == cpu_val) %>%
    group_by(Tool, Group) %>%
    summarise(Avg_RSS_per_CPU = mean(Max_RSS_KB / 1024 / cpu_val, na.rm = TRUE), .groups = "drop")
  
  if(nrow(mem_data) == 0) return(NULL)
  
  ggplot(mem_data, aes(x = Tool, y = Avg_RSS_per_CPU, fill = Tool)) +
    geom_bar(stat = "identity", color = "black", linewidth = 0.3) +
    geom_text(aes(label = sprintf("%.1f", Avg_RSS_per_CPU)), vjust = -0.3, size = 2.8) +
    scale_fill_manual(values = tool_fills) +
    facet_grid(. ~ Group, scales = "free_x", space = "free_x") +
    labs(x = NULL, y = "Avg Max RSS per CPU (MB/thread)", title = title_suffix) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 12, hjust = 0.5),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
      strip.text = element_text(face = "bold", size = 10),
      legend.position = "none",
      panel.grid.major.x = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA)
    )
}

p_mem32 <- create_memory_plot(all_data, 32, "Memory Usage at CPU32")
p_mem64 <- create_memory_plot(all_data, 64, "Memory Usage at CPU64")

# Combine memory plots side-by-side (Version One)
if(!is.null(p_mem32) && !is.null(p_mem64)) {
  title_grob <- textGrob("Memory Usage Comparison: HISAT2 vs Bowtie2/RSEM vs Salmon",
                         gp = gpar(fontface = "bold", fontsize = 14))
  p_combined_mem <- arrangeGrob(title_grob, 
                                arrangeGrob(p_mem32, p_mem64, ncol = 2),
                                nrow = 2, heights = c(0.08, 1))
  ggsave(file.path(output_dir, "Memory_Usage_CPU32_CPU64.jpeg"), p_combined_mem,
         width = 16, height = 7, dpi = 300, bg = "white")
} else if(!is.null(p_mem32)) {
  ggsave(file.path(output_dir, "Memory_Usage_CPU32.jpeg"), p_mem32,
         width = 12, height = 7, dpi = 300, bg = "white")
}

# Memory Usage Version Two (CPU32 only, Average Max RSS - not per CPU)
create_memory_plot_v2 <- function(data, cpu_val) {
  mem_data <- data %>%
    mutate(CPU_Count_adj = ifelse(Tool == "rsem-prepare-reference" & is.na(CPU_Count), cpu_val, CPU_Count)) %>%
    filter(CPU_Count_adj == cpu_val) %>%
    group_by(Tool, Group) %>%
    summarise(Avg_RSS = mean(Max_RSS_KB / 1024, na.rm = TRUE), .groups = "drop")
  
  if(nrow(mem_data) == 0) return(NULL)
  
  ggplot(mem_data, aes(x = Tool, y = Avg_RSS, fill = Tool)) +
    geom_bar(stat = "identity", color = "black", linewidth = 0.3) +
    geom_text(aes(label = sprintf("%.1f", Avg_RSS)), vjust = -0.3, size = 3) +
    scale_fill_manual(values = tool_fills) +
    facet_grid(. ~ Group, scales = "free_x", space = "free_x") +
    labs(x = NULL, y = "Average Max RSS (MB)", 
         title = "Memory Usage at CPU32",
         subtitle = "HISAT2 vs Bowtie2/RSEM vs Salmon") +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
      strip.text = element_text(face = "bold", size = 11),
      legend.position = "none",
      panel.grid.major.x = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA)
    )
}

p_mem32_v2 <- create_memory_plot_v2(all_data, 32)
if(!is.null(p_mem32_v2)) {
  ggsave(file.path(output_dir, "Memory_Usage_CPU32_V2.jpeg"), p_mem32_v2,
         width = 12, height = 7, dpi = 300, bg = "white")
}

# Memory Usage Version Three (CPU32 only, Output/Input Size Ratio)
create_io_ratio_plot <- function(data, cpu_val) {
  ratio_data <- data %>%
    mutate(CPU_Count_adj = ifelse(Tool == "rsem-prepare-reference" & is.na(CPU_Count), cpu_val, CPU_Count)) %>%
    filter(CPU_Count_adj == cpu_val, Input_Size_MB > 0) %>%
    mutate(IO_Ratio = Output_Size_MB / Input_Size_MB) %>%
    group_by(Tool, Group) %>%
    summarise(Avg_IO_Ratio = mean(IO_Ratio, na.rm = TRUE), .groups = "drop")
  
  if(nrow(ratio_data) == 0) return(NULL)
  
  ggplot(ratio_data, aes(x = Tool, y = Avg_IO_Ratio, fill = Tool)) +
    geom_bar(stat = "identity", color = "black", linewidth = 0.3) +
    geom_text(aes(label = sprintf("%.2f", Avg_IO_Ratio)), vjust = -0.3, size = 3) +
    scale_fill_manual(values = tool_fills) +
    facet_grid(. ~ Group, scales = "free_x", space = "free_x") +
    labs(x = NULL, y = "Output/Input Size Ratio", 
         title = "Output to Input Size Ratio at CPU32",
         subtitle = "HISAT2 vs Bowtie2/RSEM vs Salmon") +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
      strip.text = element_text(face = "bold", size = 11),
      legend.position = "none",
      panel.grid.major.x = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA)
    )
}

p_io_ratio <- create_io_ratio_plot(all_data, 32)
if(!is.null(p_io_ratio)) {
  ggsave(file.path(output_dir, "IO_Size_Ratio_CPU32_V3.jpeg"), p_io_ratio,
         width = 12, height = 7, dpi = 300, bg = "white")
}

# Print summary statistics
cat("\n", strrep("=", 60), "\nSUMMARY STATISTICS\n", strrep("=", 60), "\n")
for(tool in tool_order) {
  tool_data <- all_data %>% filter(Tool == tool)
  if(nrow(tool_data) > 0) {
    cat(sprintf("\n%s (%s):\n", tool, tool_config[[tool]]$group))
    cat(sprintf("  Overall: Avg User Time=%.2fs, Avg Max RSS=%.2fMB (n=%d)\n",
                mean(tool_data$User_Time_sec), mean(tool_data$Max_RSS_KB)/1024, nrow(tool_data)))
    for(cpu in c(32, 64)) {
      cpu_data <- tool_data %>% filter(CPU_Count == cpu)
      if(nrow(cpu_data) > 0) {
        cat(sprintf("  CPU%d: Avg User Time=%.2fs, Avg RSS/CPU=%.2fMB (n=%d)\n",
                    cpu, mean(cpu_data$User_Time_sec), 
                    mean(cpu_data$Max_RSS_KB/1024/cpu), nrow(cpu_data)))
      }
    }
  }
}

cat(sprintf("\nGraphs saved to: %s\n", output_dir))
