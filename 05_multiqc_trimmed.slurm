#!/bin/bash
#SBATCH --job-name=multiqc_trimmed
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=1:00:00
#SBATCH --partition=standard
#SBATCH --account=YOUR_HPC_ACCOUNT
#SBATCH --output=../logs/05_multiqc_trimmed_%j.out
#SBATCH --error=../logs/05_multiqc_trimmed_%j.err

# Aggregate FastQC reports for trimmed reads with MultiQC

module load multiqc/1.27.1

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
QC_DIR=${BASE_DIR}/04.FastQC_trimmed

echo "Running MultiQC on trimmed FastQC reports..."

cd ${QC_DIR}
multiqc . --filename multiqc_trimmed_report

echo "MultiQC complete!"
echo "Report: ${QC_DIR}/multiqc_trimmed_report.html"
echo ""
echo "Compare this report with multiqc_raw_report.html to verify trimming improved quality!"
