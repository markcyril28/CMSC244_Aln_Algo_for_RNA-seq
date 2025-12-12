#!/bin/bash

# Logging Utilities - Four-version logging system for pipeline tracking

set -euo pipefail

# Logging Configuration
RUN_ID="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="logs/log_files"
TIME_DIR="logs/time_logs"
SPACE_DIR="logs/space_logs"
SPACE_TIME_DIR="logs/space_time_logs"
LOG_FILE="$LOG_DIR/pipeline_${RUN_ID}_full_log.log"
TIME_FILE="$TIME_DIR/pipeline_${RUN_ID}_time_metrics.csv"
TIME_TEMP="$TIME_DIR/.time_temp_${RUN_ID}.txt"
SPACE_FILE="$SPACE_DIR/pipeline_${RUN_ID}_space_metrics.csv"
SPACE_TIME_FILE="$SPACE_TIME_DIR/pipeline_${RUN_ID}_combined_metrics.csv"

# Logging Functions
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { local level="$1"; shift; printf '[%s] [%s] %s\n' "$(timestamp)" "$level" "$*"; }
log_info() { log INFO "$@"; }
log_warn() { log WARN "$@"; }
log_error() { log ERROR "$@"; }
log_step() { log INFO "=============== $* ==============="; }

setup_logging() {
	local clear_logs="${1:-false}"
	
	if [[ "${LOGGING_INITIALIZED:-}" == "true" ]]; then
		log_info "Logging already initialized, skipping setup"
		return 0
	fi
	
	keep_bam_global="${keep_bam_global:-n}"
	mkdir -p "$LOG_DIR" "$TIME_DIR" "$SPACE_DIR" "$SPACE_TIME_DIR"
	
	if [[ "$clear_logs" == "true" ]]; then
		rm -f "$LOG_DIR"/*.log 2>/dev/null || true
		rm -f "$TIME_DIR"/*.csv 2>/dev/null || true
		rm -f "$SPACE_DIR"/*.csv 2>/dev/null || true
		rm -f "$SPACE_TIME_DIR"/*.csv 2>/dev/null || true
		echo "Previous logs cleared"
	fi
	
	[[ ! -f "$TIME_FILE" ]] && echo "Timestamp,Command,Elapsed_Time_sec,CPU_Percent,Max_RSS_KB,User_Time_sec,System_Time_sec,Exit_Status" > "$TIME_FILE"
	[[ ! -f "$SPACE_FILE" ]] && echo "Timestamp,Type,Path,Size_KB,Size_MB,Size_GB,File_Count,Description" > "$SPACE_FILE"
	[[ ! -f "$SPACE_TIME_FILE" ]] && echo "Timestamp,Command,Elapsed_Time_sec,CPU_Percent,Max_RSS_KB,User_Time_sec,System_Time_sec,Input_Size_MB,Output_Size_MB,Exit_Status" > "$SPACE_TIME_FILE"
	
	log_choice="${log_choice:-1}"
	if [[ "$log_choice" == "2" ]]; then
		exec >"$LOG_FILE" 2>&1
	else
		exec > >(tee -a "$LOG_FILE") 2>&1
	fi
	
	export LOGGING_INITIALIZED="true"
	log_info "Logging to: $LOG_FILE"
	log_info "Time metrics to: $TIME_FILE"
	log_info "Space metrics to: $SPACE_FILE"
	log_info "Combined metrics to: $SPACE_TIME_FILE"
}

trap 'log_error "Command failed (rc=$?) at line $LINENO: ${BASH_COMMAND:-unknown}"; exit 1' ERR
trap 'log_info "Log File: $LOG_FILE"; log_info "Time metrics: $TIME_FILE"' EXIT

run_with_space_time_log() {
	local input_path="" output_path=""
	
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--input) input_path="$2"; shift 2 ;;
			--output) output_path="$2"; shift 2 ;;
			*) break ;;
		esac
	done
	
	local cmd_short="$*"
	local start_ts="$(timestamp)"
	local input_size_mb="0" output_size_mb="0"
	
	if [[ -n "$input_path" ]]; then
		local input_kb=$(du -sk "$input_path" 2>/dev/null | awk '{print $1}')
		input_size_mb=$(echo "scale=2; $input_kb / 1024" | bc)
	fi
	
	mkdir -p "$TIME_DIR"
	local exit_code=0
	/usr/bin/time -v "$@" >> "$LOG_FILE" 2> "$TIME_TEMP" || exit_code=$?
	cat "$TIME_TEMP" >> "$LOG_FILE" 2>&1
	
	local elapsed_time=$(grep "Elapsed (wall clock)" "$TIME_TEMP" | awk '{print $NF}' | awk -F: '{if (NF==3) print ($1*3600)+($2*60)+$3; else if (NF==2) print ($1*60)+$2; else print $1}')
	local cpu_percent=$(grep "Percent of CPU" "$TIME_TEMP" | awk '{print $NF}' | tr -d '%')
	local max_rss=$(grep "Maximum resident set size" "$TIME_TEMP" | awk '{print $NF}')
	local user_time=$(grep "User time" "$TIME_TEMP" | awk '{print $NF}')
	local system_time=$(grep "System time" "$TIME_TEMP" | awk '{print $NF}')
	
	if [[ -n "$output_path" ]]; then
		local output_kb=$(du -sk "$output_path" 2>/dev/null | awk '{print $1}')
		output_size_mb=$(echo "scale=2; $output_kb / 1024" | bc)
	fi
	
	echo "${start_ts},\"${cmd_short}\",${elapsed_time:-0},${cpu_percent:-0},${max_rss:-0},${user_time:-0},${system_time:-0},${exit_code}" >> "$TIME_FILE"
	echo "${start_ts},\"${cmd_short}\",${elapsed_time:-0},${cpu_percent:-0},${max_rss:-0},${user_time:-0},${system_time:-0},${input_size_mb},${output_size_mb},${exit_code}" >> "$SPACE_TIME_FILE"
	rm -f "$TIME_TEMP"
	
	return $exit_code
}

# Space Logging Functions
log_file_size() {
	local file_path="$1"
	local description="${2:-}"
	local type="FILE"
	[[ -d "$file_path" ]] && type="DIR"
	
	local size_kb=$(du -sk "$file_path" 2>/dev/null | awk '{print $1}')
	local size_mb=$(echo "scale=2; $size_kb / 1024" | bc)
	local size_gb=$(echo "scale=2; $size_kb / 1048576" | bc)
	local file_count="-"
	[[ -d "$file_path" ]] && file_count=$(find "$file_path" -type f 2>/dev/null | wc -l)
	
	echo "$(timestamp),${type},\"${file_path}\",${size_kb},${size_mb},${size_gb},${file_count},\"${description}\"" >> "$SPACE_FILE"
	log_info "Space logged: $file_path = ${size_mb}MB"
}

log_input_output_size() {
	local input_path="$1"
	local output_path="$2"
	local step_description="${3:-}"
	
	log_info "Logging space for: $step_description"
	log_file_size "$input_path" "${step_description} - INPUT"
	log_file_size "$output_path" "${step_description} - OUTPUT"
}

log_disk_usage() {
	local workspace_path="${1:-.}"
	local description="${2:-Workspace disk usage}"
	log_file_size "$workspace_path" "$description"
}
