#!/bin/bash
#SBATCH --job-name=multiqc_align
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G
#SBATCH --time=1:15:00
#SBATCH --partition=standard
#SBATCH --output=../logs/08_multiqc_align_%j.out
#SBATCH --error=../logs/08_multiqc_align_%j.err

# Aggregate STAR alignment logs with MultiQC

module load multiqc

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
ALIGN_DIR=${BASE_DIR}/05.Alignment

echo "Running MultiQC on STAR alignment logs..."

cd ${ALIGN_DIR}
multiqc . --filename multiqc_alignment_report

echo "MultiQC complete!"
echo "Report: ${ALIGN_DIR}/multiqc_alignment_report.html"
