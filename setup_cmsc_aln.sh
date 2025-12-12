#!/bin/bash
# CMSC244 Conda Environment Setup
set -euo pipefail

ENV_NAME="cmsc_aln"
PYTHON_VERSION="3.10"

eval "$(conda shell.bash hook)"

# Detect package manager
PKG_MGR="conda"
command -v mamba &> /dev/null && PKG_MGR="mamba"
echo "Using: $PKG_MGR"

# Create environment
$PKG_MGR create -n "$ENV_NAME" python="$PYTHON_VERSION" -y || conda create -n "$ENV_NAME" python="$PYTHON_VERSION" -y
conda activate "$ENV_NAME"

# Install packages
for pkg in numpy matplotlib pandas; do
    $PKG_MGR install -n "$ENV_NAME" $pkg -y 2>/dev/null || pip install $pkg
done
