#!/bin/bash
#SBATCH --job-name=deseq2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=5
#SBATCH --mem=40G
#SBATCH --time=5:00:00
#SBATCH --partition=standard
#SBATCH --account=${HPC_ACCOUNT:-$USER}
#SBATCH --output=../logs/07_deseq2_%j.out
#SBATCH --error=../logs/07_deseq2_%j.err

# Run DESeq2 analysis in R

# Load R module (adjust version as needed)
module load miniforge/24.11.3-py3.12

# Activate conda environment with R and DESeq2
# Note: You may need to create this environment first
# conda create -n rnaseq_r -c conda-forge -c bioconda r-base r-deseq2 r-ggplot2 r-pheatmap r-dplyr bioconductor-enhancedvolcano

# If you haven't created the environment yet, uncomment:
# conda create -y -n rnaseq_r -c conda-forge -c bioconda r-base r-deseq2 r-ggplot2 r-pheatmap r-dplyr r-rcolorbrewer bioconductor-enhancedvolcano

source activate rnaseq_r

# Copy experimental design to scratch
BASE_DIR=/scratch/${USER}/BHB_complete
cp experimental_design.csv ${BASE_DIR}/

# Run R script
cd ${BASE_DIR}
Rscript 07_deseq2_analysis.R

echo "DESeq2 analysis complete!"
