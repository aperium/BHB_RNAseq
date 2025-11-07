#!/bin/bash
#SBATCH --job-name=multiqc_raw
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G
#SBATCH --time=1:15:00
#SBATCH --partition=standard
#SBATCH --output=../logs/02_multiqc_raw_%j.out
#SBATCH --error=../logs/02_multiqc_raw_%j.err

# Aggregate FastQC reports with MultiQC

module load multiqc

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
QC_DIR=${BASE_DIR}/03.FastQC_raw

echo "Running MultiQC on raw FastQC reports..."

cd ${QC_DIR}
multiqc . --filename multiqc_raw_report

echo "MultiQC complete!"
echo "Report: ${QC_DIR}/multiqc_raw_report.html"
