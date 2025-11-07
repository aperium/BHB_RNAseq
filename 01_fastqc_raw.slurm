#!/bin/bash
#SBATCH --job-name=fastqc_raw
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=40G
#SBATCH --time=5:00:00
#SBATCH --partition=standard
#SBATCH --output=../logs/01_fastqc_raw_%j.out
#SBATCH --error=../logs/01_fastqc_raw_%j.err

# Quality control of raw reads with FastQC

module load fastqc

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
SCRIPT_DIR=${BASE_DIR}/BHB_RNAseq
RAW_DIR=${BASE_DIR}/01.RawData
QC_DIR=${BASE_DIR}/03.FastQC_raw
mkdir -p ${QC_DIR}

echo "Starting FastQC on raw reads..."
echo "Input directory: ${RAW_DIR}"
echo "Output directory: ${QC_DIR}"

# Run FastQC on all fastq.gz files
fastqc ${RAW_DIR}/*/*.fq.gz \
    --outdir ${QC_DIR} \
    --threads 20

echo "FastQC complete!"
echo "Results saved to: ${QC_DIR}"
