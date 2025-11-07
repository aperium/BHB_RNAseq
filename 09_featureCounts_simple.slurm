#!/bin/bash
#SBATCH --job-name=featureCounts
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=40G
#SBATCH --time=2:30:00
#SBATCH --partition=standard
#SBATCH --output=../logs/09_featureCounts_simple_%j.out
#SBATCH --error=../logs/09_featureCounts_simple_%j.err

# Exit immediately if any command fails
set -e
set -u
set -o pipefail

module load samtools

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
ALIGN_DIR=${BASE_DIR}/05.Alignment
COUNT_DIR=${BASE_DIR}/06.5.Counts
mkdir -p ${COUNT_DIR}

# Check if alignment directory exists
if [ ! -d "${ALIGN_DIR}" ]; then
    echo "ERROR: Alignment directory not found: ${ALIGN_DIR}"
    exit 1
fi

featureCounts -T 20 -p -B -a 00.Reference/combined_annotation.gtf -o "${COUNT_DIR}/featurecounts_output.txt" ${ALIGN_DIR}/*/*.bam

module purge
