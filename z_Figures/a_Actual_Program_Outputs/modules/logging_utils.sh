#!/bin/bash

set -euo pipefail

RUN_ID="$(date +%Y%m%d_%H%M%S)"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { local level="$1"; shift; printf '[%s] [%s] %s\n' "$(timestamp)" "$level" "$*"; }
log_info() { log INFO "$@"; }
log_warn() { log WARN "$@"; }
log_error() { log ERROR "$@"; }
log_step() { log INFO "=============== $* ==============="; }

setup_logging() {
	# Determine project root from script location
	local util_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local project_root="$(cd "$util_dir/../.." && pwd)"
	local log_dir="$project_root/z_analysis/analysis_logs"
	local log_file="$log_dir/analysis_${RUN_ID}.log"
	
	mkdir -p "$log_dir"
	exec > >(tee -a "$log_file") 2>&1
	log_info "Logging to: $log_file"
	
	# Export for trap handlers
	export LOG_FILE="$log_file"
}

trap 'log_error "Command failed at line $LINENO: ${BASH_COMMAND:-unknown}"; exit 1' ERR
trap 'log_info "Script finished. See log: $LOG_FILE"' EXIT
