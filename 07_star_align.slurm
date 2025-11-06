#!/bin/bash
#SBATCH --job-name=star_align
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=48G
#SBATCH --time=5:00:00
#SBATCH --partition=standard
#SBATCH --array=1-42
#SBATCH --output=../logs/04_star_align_%A_%a.out
#SBATCH --error=../logs/04_star_align_%A_%a.err

# Exit immediately if any command fails
set -e
set -u
set -o pipefail

# STAR alignment for paired-end reads
# This is an array job - one task per sample (42 samples)

module load star
module load samtools

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
TRIMMED_DIR=${BASE_DIR}/02.Trimmed
INDEX_DIR=${BASE_DIR}/00.Reference/STAR_index
ALIGN_DIR=${BASE_DIR}/05.Alignment
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

# Find the trimmed read files (paired outputs from Trimmomatic)
R1=${TRIMMED_DIR}/${SAMPLE}_1_paired.fq.gz
R2=${TRIMMED_DIR}/${SAMPLE}_2_paired.fq.gz

if [ ! -f "$R1" ] || [ ! -f "$R2" ]; then
    echo "ERROR: Could not find trimmed read files for ${SAMPLE}"
    echo "Expected: ${R1}"
    echo "Expected: ${R2}"
    exit 1
fi

echo "R1: ${R1}"
echo "R2: ${R2}"

# Create sample output directory
OUT_DIR=${ALIGN_DIR}/${SAMPLE}
mkdir -p ${OUT_DIR}

# Run STAR alignment
STAR --runThreadN 32 \
    --limitBAMsortRAM 40000000000 \
    --genomeDir ${INDEX_DIR} \
    --readFilesIn ${R1} ${R2} \
    --readFilesCommand zcat \
    --outFileNamePrefix ${OUT_DIR}/${SAMPLE}_ \
    --outSAMtype BAM SortedByCoordinate \
    --outSAMunmapped Within \
    --outSAMattributes Standard \
    --quantMode GeneCounts

# Verify STAR output exists
BAM_FILE="${OUT_DIR}/${SAMPLE}_Aligned.sortedByCoord.out.bam"
COUNTS_FILE="${OUT_DIR}/${SAMPLE}_ReadsPerGene.out.tab"

if [ ! -f "${BAM_FILE}" ]; then
    echo "ERROR: STAR alignment failed - BAM file not created: ${BAM_FILE}"
    exit 1
fi

if [ ! -f "${COUNTS_FILE}" ]; then
    echo "ERROR: STAR alignment failed - gene counts file not created: ${COUNTS_FILE}"
    exit 1
fi

# Index the BAM file
samtools index ${BAM_FILE}

# Verify index was created
if [ ! -f "${BAM_FILE}.bai" ]; then
    echo "ERROR: Failed to create BAM index: ${BAM_FILE}.bai"
    exit 1
fi

echo "===== ALIGNMENT COMPLETE FOR ${SAMPLE} ====="
echo "BAM file: ${BAM_FILE}"
echo "Gene counts: ${COUNTS_FILE}"
echo "BAM index: ${BAM_FILE}.bai"
echo "============================================="
