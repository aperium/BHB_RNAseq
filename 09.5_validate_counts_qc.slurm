#!/bin/bash
#SBATCH --job-name=julia_qc
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:15:00
#SBATCH --partition=standard
#SBATCH --output=../logs/09.5_julia_qc_%j.out
#SBATCH --error=../logs/09.5_julia_qc_%j.err

# =============================================================================
# Julia-based QC/Validation Script (Phase 1)
# =============================================================================
#
# This script runs Julia-based quality control on count data
# It does NOT replace any existing pipeline steps - it's purely additive QC
#
# Run after: 09_featureCounts.slurm
# Run before: 10_run_deseq2.slurm (optional - for validation only)

set -e
set -u
set -o pipefail

echo "=========================================="
echo "Julia QC Validation"
echo "=========================================="
echo "Job ID: ${SLURM_JOB_ID}"
echo "Node: ${SLURMD_NODENAME}"
echo "Start time: $(date)"
echo ""

# Load Julia module
module load julia/1.11.6

# Check Julia version
echo "Julia version:"
julia --version
echo ""

# Set base directory
BASE_DIR=/scratch/${USER}/BHB_complete

echo "Base directory: ${BASE_DIR}"
echo ""

# Check if Julia packages are installed
echo "Checking Julia package environment..."
julia -e 'using Pkg; pkg"status DataFrames CSV Statistics"' || {
    echo ""
    echo "Installing required Julia packages..."
    julia -e 'using Pkg; Pkg.add(["DataFrames", "CSV", "Statistics"])'
    echo "✓ Packages installed"
}
echo ""

# Run the QC script
echo "Running Julia QC validation script..."
echo "=========================================="
echo ""

julia ${BASE_DIR}/BHB_RNAseq/scripts/validate_counts_qc.jl ${BASE_DIR}

EXIT_CODE=$?

echo ""
echo "=========================================="
echo "Julia QC Complete"
echo "Exit code: ${EXIT_CODE}"
echo "End time: $(date)"
echo "=========================================="

exit ${EXIT_CODE}
