#!/bin/bash
#SBATCH --job-name=star_align
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=4:00:00
#SBATCH --partition=standard
#SBATCH --account=YOUR_HPC_ACCOUNT
#SBATCH --array=1-42
#SBATCH --output=../logs/04_star_align_%A_%a.out
#SBATCH --error=../logs/04_star_align_%A_%a.err

# STAR alignment for paired-end reads
# This is an array job - one task per sample (42 samples)

module load star/2.7.11b
module load samtools/1.21

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
RAW_DIR=${BASE_DIR}/01.RawData
INDEX_DIR=${BASE_DIR}/00.Reference/STAR_index
ALIGN_DIR=${BASE_DIR}/04.Alignment
mkdir -p ${ALIGN_DIR}

# Sample names array
SAMPLES=(
    log_LM_3 log_C_1 log_C_2 stat_N_1 stat_N_2 stat_N_3
    stat_B_1 stat_B_2 stat_B_3 stat_L_1 stat_L_2 stat_M_1
    stat_M_3 stat_BM_1 stat_BM_2 stat_BM_3 stat_LM_1 stat_LM_2
    stat_LM_3 stat_C_1 stat_C_2 stat_C_3 log_C_3 stat_L_3
    stat_M_2 log_N_1 log_N_2 log_N_3 log_B_1 log_B_2
    log_B_3 log_L_1 log_L_2 log_L_3 log_M_1 log_M_2
    log_M_3 log_BM_1 log_BM_2 log_BM_3 log_LM_1 log_LM_2
)

# Get sample name for this array task
SAMPLE=${SAMPLES[$SLURM_ARRAY_TASK_ID-1]}

echo "Processing sample: ${SAMPLE}"
echo "Array task ID: ${SLURM_ARRAY_TASK_ID}"

# Find the read files (adjust path pattern based on Novogene structure)
R1=$(find ${RAW_DIR} -name "${SAMPLE}*_1.fq.gz" | head -1)
R2=$(find ${RAW_DIR} -name "${SAMPLE}*_2.fq.gz" | head -1)

if [ -z "$R1" ] || [ -z "$R2" ]; then
    echo "ERROR: Could not find read files for ${SAMPLE}"
    echo "Searched for: ${RAW_DIR}/*/${SAMPLE}*_[12].fq.gz"
    exit 1
fi

echo "R1: ${R1}"
echo "R2: ${R2}"

# Create sample output directory
OUT_DIR=${ALIGN_DIR}/${SAMPLE}
mkdir -p ${OUT_DIR}

# Run STAR alignment
STAR --runThreadN 8 \
    --genomeDir ${INDEX_DIR} \
    --readFilesIn ${R1} ${R2} \
    --readFilesCommand zcat \
    --outFileNamePrefix ${OUT_DIR}/${SAMPLE}_ \
    --outSAMtype BAM SortedByCoordinate \
    --outSAMunmapped Within \
    --outSAMattributes Standard \
    --quantMode GeneCounts

# Index the BAM file
samtools index ${OUT_DIR}/${SAMPLE}_Aligned.sortedByCoord.out.bam

echo "Alignment complete for ${SAMPLE}!"
echo "Output: ${OUT_DIR}/${SAMPLE}_Aligned.sortedByCoord.out.bam"
