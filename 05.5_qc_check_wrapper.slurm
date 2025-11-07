#!/bin/bash
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --partition=standard
#SBATCH --account=jsmith_lab
#SBATCH -o /scratch/%u/BHB_complete/logs/05.5_qc_check_%j.out
#SBATCH -e /scratch/%u/BHB_complete/logs/05.5_qc_check_%j.err

# This wrapper runs the quality check script and exits with its exit code
# If QC fails, this job fails, blocking downstream jobs

cd /scratch/$USER/BHB_complete/BHB_RNAseq

echo "========================================"
echo "Running Trimming Quality Check"
echo "========================================"
echo ""

if bash 05.5_check_trimming_quality.sh; then
    echo ""
    echo "QC check passed - downstream jobs will proceed"
    exit 0
else
    echo ""
    echo "QC check FAILED - downstream jobs will be blocked"
    echo "Review reports and either:"
    echo "  1. Fix trimming parameters and rerun"
    echo "  2. Use SKIP_QC_CHECK=1 to bypass (not recommended)"
    exit 1
fi
