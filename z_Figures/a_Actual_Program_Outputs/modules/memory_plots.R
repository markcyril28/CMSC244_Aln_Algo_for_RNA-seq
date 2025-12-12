#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(readr)

palette <- c("#FFFFFF", "#FFEB3B", "#CDDC39", "#8BC34A", "#4CAF50", 
             "#009688", "#00BCD4", "#3F51B5", "#673AB7", "#4A148C")


  
  # Memory_Per_CPU
  if(all(c("Max_RSS_KB", "Command") %in% names(data))) {
    data$CPU_Count <- sapply(data$Command, function(cmd) {
      cpu <- as.numeric(sub(".*(?:-p |--threads=|-@ )(\\d+).*", "\\1", cmd, perl=TRUE))
      if(is.na(cpu)) 1 else cpu
    })
    data_cpu <- data %>%
      filter(!is.na(CPU_Count) & CPU_Count > 1) %>%
      mutate(RSS_per_CPU = Max_RSS_KB / CPU_Count) %>%
      group_by(CPU_Count) %>%
      summarise(Avg_RSS_per_CPU = mean(RSS_per_CPU, na.rm = TRUE), .groups = "drop") %>%
      arrange(CPU_Count)
    
    if(nrow(data_cpu) > 0) {
      p <- ggplot(data_cpu, aes(x = factor(CPU_Count), y = Avg_RSS_per_CPU)) +
        geom_bar(stat = "identity", fill = palette[7]) +
        labs(x = "CPU Count (cores)", y = "Avg Max RSS per CPU (KB/core)") +
        theme_minimal() +
        theme(plot.margin = unit(rep(1, 4), "inches"),
              panel.background = element_rect(fill = "white"),
              plot.background = element_rect(fill = "white"))
      
    ggsave(file.path(output_dir, "Memory_Per_CPU.jpeg"), p, 
           width = 10, height = 6, dpi = 300, bg = "white")
    }
  }
}

create_input_size_list <- function(base_dir, output_dir, programs = NULL) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  
  all_data_list <- list()
  
  if(is.null(programs)) {
    csv_files <- list.files(base_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
    filename <- "all_programs_combined"
  } else {
    csv_files <- c()
    for(prog in programs) {
      prog_files <- list.files(file.path(base_dir, prog), pattern = paste0("^", prog, "\\.csv$"), 
                               full.names = TRUE)
      csv_files <- c(csv_files, prog_files)
    }
    filename <- paste(programs, collapse = "_")
  }
  
  for(csv in csv_files) {
    if(file.exists(csv)) {
      df <- tryCatch({
        read_csv(csv, show_col_types = FALSE, col_types = cols(.default = col_character()))
      }, error = function(e) NULL)
      
      if(!is.null(df) && nrow(df) > 0) {
        # Convert numeric columns
        numeric_cols <- c("Elapsed_Time_sec", "CPU_Percent", "Max_RSS_KB", 
                          "User_Time_sec", "System_Time_sec", "Input_Size_MB", 
                          "Output_Size_MB", "Exit_Status")
        for(col in numeric_cols) {
          if(col %in% names(df)) {
            df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
          }
        }
        df$Program <- basename(dirname(csv))
        all_data_list[[length(all_data_list) + 1]] <- df
      }
    }
  }
  
  all_data <- if(length(all_data_list) > 0) bind_rows(all_data_list) else data.frame()
  
  if(nrow(all_data) > 0 && "Input_Size_MB" %in% names(all_data)) {
    unique_sizes <- all_data %>%
      select(Input_Size_MB, Program) %>%
      distinct() %>%
      arrange(Input_Size_MB)
    
    write.table(unique_sizes, 
                file.path(output_dir, paste0(filename, ".txt")), 
                row.names = FALSE, quote = FALSE, sep = "\t")
    
    size_stats <- all_data %>%
      summarise(
        Total_Input_MB = sum(Input_Size_MB, na.rm = TRUE),
        Min_Input_MB = min(Input_Size_MB, na.rm = TRUE),
        Max_Input_MB = max(Input_Size_MB, na.rm = TRUE),
        Mean_Input_MB = mean(Input_Size_MB, na.rm = TRUE),
        Median_Input_MB = median(Input_Size_MB, na.rm = TRUE)
      )
    
    write.table(size_stats, 
                file.path(output_dir, paste0(filename, "_stats.txt")), 
                row.names = FALSE, quote = FALSE, sep = "\t")
  }
}

create_output_size_comparison <- function(base_dir, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  
  programs <- list(
    list(names = c("hisat2", "hisat2-build", "samtools_sort"), label = "hisat2+hisat2-build+samtools_sort"),
    list(names = c("salmon_quant"), label = "salmon_quant"),
    list(names = c("rsem-calculate-expression"), label = "rsem-calculate-expression")
  )
  
  all_data_list <- list()
  
  for(prog_group in programs) {
    group_data_list <- list()
    for(prog in prog_group$names) {
      csv_file <- file.path(base_dir, prog, paste0(prog, ".csv"))
      if(file.exists(csv_file)) {
        df <- tryCatch({
          read_csv(csv_file, show_col_types = FALSE, col_types = cols(.default = col_character()))
        }, error = function(e) NULL)
        
        if(!is.null(df) && nrow(df) > 0) {
          # Convert numeric columns
          numeric_cols <- c("Elapsed_Time_sec", "CPU_Percent", "Max_RSS_KB", 
                            "User_Time_sec", "System_Time_sec", "Input_Size_MB", 
                            "Output_Size_MB", "Exit_Status")
          for(col in numeric_cols) {
            if(col %in% names(df)) {
              df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
            }
          }
          group_data_list[[length(group_data_list) + 1]] <- df
        }
      }
    }
    if(length(group_data_list) > 0) {
      group_data <- bind_rows(group_data_list)
      group_data$Program <- prog_group$label
      all_data_list[[length(all_data_list) + 1]] <- group_data
    }
  }
  
  all_data <- if(length(all_data_list) > 0) bind_rows(all_data_list) else data.frame()
  
  if(nrow(all_data) > 0 && "Max_RSS_KB" %in% names(all_data)) {
    memory_summary <- all_data %>%
      group_by(Program) %>%
      summarise(
        Avg_Max_RSS_KB = mean(Max_RSS_KB, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(desc(Avg_Max_RSS_KB))
    
    p <- ggplot(memory_summary, aes(x = reorder(Program, Avg_Max_RSS_KB), y = Avg_Max_RSS_KB, fill = Program)) +
      geom_bar(stat = "identity") +
      scale_fill_manual(values = palette[c(5,6,7)]) +
      labs(x = "Program", y = "Average Max RSS (KB)") +
      theme_minimal() +
      theme(plot.margin = unit(rep(1, 4), "inches"),
            panel.background = element_rect(fill = "white"),
            plot.background = element_rect(fill = "white"),
            axis.text.x = element_text(angle = 30, hjust = 1),
            legend.position = "none")
    
    ggsave(file.path(output_dir, "Output_Size_Comparison.jpeg"), p, 
           width = 10, height = 6, dpi = 300, bg = "white")
    
    write.table(memory_summary, 
                file.path(output_dir, "output_size_comparison.txt"), 
                row.names = FALSE, quote = FALSE, sep = "\t")
  }
}

if(length(args) >= 3) {
  if(args[1] == "program") {
    create_memory_plots(args[2], args[3], args[4])
  } else if(args[1] == "input_list") {
    programs <- if(length(args) > 3) args[4:length(args)] else NULL
    create_input_size_list(args[2], args[3], programs)
  } else if(args[1] == "output_comparison") {
    create_output_size_comparison(args[2], args[3])
  }
}
