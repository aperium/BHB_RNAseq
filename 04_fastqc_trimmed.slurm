#!/bin/bash
#SBATCH --job-name=fastqc_trimmed
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=40G
#SBATCH --time=5:00:00
#SBATCH --partition=standard
#SBATCH --output=../logs/04_fastqc_trimmed_%j.out
#SBATCH --error=../logs/04_fastqc_trimmed_%j.err

# Quality control of trimmed reads with FastQC

module load fastqc/0.12.1

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
TRIMMED_DIR=${BASE_DIR}/02.Trimmed
QC_DIR=${BASE_DIR}/04.FastQC_trimmed
mkdir -p ${QC_DIR}

echo "Starting FastQC on trimmed reads..."
echo "Input directory: ${TRIMMED_DIR}"
echo "Output directory: ${QC_DIR}"

# Run FastQC on all trimmed fastq.gz files
fastqc ${TRIMMED_DIR}/*.fq.gz \
    --outdir ${QC_DIR} \
    --threads 20

echo "FastQC complete!"
echo "Results saved to: ${QC_DIR}"
