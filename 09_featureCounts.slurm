#!/bin/bash
#SBATCH --job-name=featureCounts
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=40G
#SBATCH --time=2:30:00
#SBATCH --partition=standard
#SBATCH --output=../logs/09_featureCounts_%j.out
#SBATCH --error=../logs/09_featureCounts_%j.err

# Exit immediately if any command fails
set -e
set -u
set -o pipefail

# Count reads per gene using featureCounts (subread package)
# Note: UVA HPC doesn't have subread as a module, so we'll use STAR's built-in counts
# and create the count matrix from STAR GeneCounts output

module load samtools

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
ALIGN_DIR=${BASE_DIR}/05.Alignment
COUNT_DIR=${BASE_DIR}/06.Counts
mkdir -p ${COUNT_DIR}

echo "Extracting gene counts from STAR output..."
echo "Alignment directory: ${ALIGN_DIR}"
echo "Count output directory: ${COUNT_DIR}"

# Check if alignment directory exists
if [ ! -d "${ALIGN_DIR}" ]; then
    echo "ERROR: Alignment directory not found: ${ALIGN_DIR}"
    exit 1
fi

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

# Copy individual count files and track missing files
MISSING_COUNT=0
FOUND_COUNT=0

for SAMPLE in "${SAMPLES[@]}"; do
    COUNT_FILE=${ALIGN_DIR}/${SAMPLE}/${SAMPLE}_ReadsPerGene.out.tab
    if [ -f "$COUNT_FILE" ]; then
        cp ${COUNT_FILE} ${COUNT_DIR}/${SAMPLE}_counts.txt
        echo "✓ Copied counts for ${SAMPLE}"
        ((FOUND_COUNT++))
    else
        echo "ERROR: Count file not found for ${SAMPLE}: ${COUNT_FILE}"
        ((MISSING_COUNT++))
    fi
done

echo ""
echo "Summary: Found ${FOUND_COUNT} count files, missing ${MISSING_COUNT}"

# Exit with error if any count files are missing
if [ ${MISSING_COUNT} -gt 0 ]; then
    echo "ERROR: Cannot proceed - ${MISSING_COUNT} samples are missing count files"
    echo "Please check that STAR alignment completed successfully for all samples"
    exit 1
fi

# Create combined count matrix (unstranded - column 2)
# Column 1: gene ID
# Column 2: counts for unstranded
# Column 3: counts for stranded (forward)
# Column 4: counts for stranded (reverse)

echo "Creating combined count matrix..."

# Get gene names from first sample
FIRST_SAMPLE=${SAMPLES[0]}
FIRST_COUNT_FILE="${COUNT_DIR}/${FIRST_SAMPLE}_counts.txt"

if [ ! -f "${FIRST_COUNT_FILE}" ]; then
    echo "ERROR: First sample count file not found: ${FIRST_COUNT_FILE}"
    exit 1
fi

# Check that the count file has data (more than just header lines)
LINE_COUNT=$(wc -l < "${FIRST_COUNT_FILE}")
if [ ${LINE_COUNT} -le 4 ]; then
    echo "ERROR: Count file appears empty or corrupted: ${FIRST_COUNT_FILE}"
    echo "Expected >4 lines, found ${LINE_COUNT}"
    exit 1
fi

awk 'NR>4 {print $1}' ${FIRST_COUNT_FILE} > ${COUNT_DIR}/gene_ids.tmp

# Verify gene IDs were extracted
GENE_COUNT=$(wc -l < ${COUNT_DIR}/gene_ids.tmp)
if [ ${GENE_COUNT} -eq 0 ]; then
    echo "ERROR: No gene IDs extracted from ${FIRST_COUNT_FILE}"
    exit 1
fi

echo "Extracted ${GENE_COUNT} gene IDs from ${FIRST_SAMPLE}"

# Start building the matrix with gene IDs
cp ${COUNT_DIR}/gene_ids.tmp ${COUNT_DIR}/counts_matrix_unstranded.txt

# Add each sample's counts (column 2 = unstranded)
for SAMPLE in "${SAMPLES[@]}"; do
    echo "Adding ${SAMPLE}..."
    awk 'NR>4 {print $2}' ${COUNT_DIR}/${SAMPLE}_counts.txt > ${COUNT_DIR}/${SAMPLE}.tmp
    paste ${COUNT_DIR}/counts_matrix_unstranded.txt ${COUNT_DIR}/${SAMPLE}.tmp > ${COUNT_DIR}/temp.txt
    mv ${COUNT_DIR}/temp.txt ${COUNT_DIR}/counts_matrix_unstranded.txt
done

# Add header
HEADER="GeneID\t$(printf '%s\t' "${SAMPLES[@]}" | sed 's/\t$//')"
echo -e "$HEADER" | cat - ${COUNT_DIR}/counts_matrix_unstranded.txt > ${COUNT_DIR}/temp.txt
mv ${COUNT_DIR}/temp.txt ${COUNT_DIR}/counts_matrix_unstranded.txt

# Clean up temporary files
rm -f ${COUNT_DIR}/*.tmp

# Validate output file
OUTPUT_FILE="${COUNT_DIR}/counts_matrix_unstranded.txt"

if [ ! -f "${OUTPUT_FILE}" ]; then
    echo "ERROR: Output count matrix was not created: ${OUTPUT_FILE}"
    exit 1
fi

# Check dimensions
MATRIX_LINES=$(wc -l < ${OUTPUT_FILE})
MATRIX_COLS=$(head -n 1 ${OUTPUT_FILE} | awk '{print NF}')
EXPECTED_COLS=$((${#SAMPLES[@]} + 1))  # samples + gene ID column

echo ""
echo "===== COUNT MATRIX CREATED SUCCESSFULLY ====="
echo "Output: ${OUTPUT_FILE}"
echo "Dimensions: ${MATRIX_LINES} genes x ${MATRIX_COLS} columns"
echo "Expected: ${GENE_COUNT} genes x ${EXPECTED_COLS} columns (1 GeneID + ${#SAMPLES[@]} samples)"

# Validate column count
if [ ${MATRIX_COLS} -ne ${EXPECTED_COLS} ]; then
    echo "WARNING: Column count mismatch! Expected ${EXPECTED_COLS}, got ${MATRIX_COLS}"
    echo "This may indicate some samples failed to be added to the matrix"
fi

# Validate we have genes (more than just header)
if [ ${MATRIX_LINES} -le 1 ]; then
    echo "ERROR: Count matrix appears to only have a header, no gene data"
    exit 1
fi

echo "Validation: ✓ Count matrix has data for $(($MATRIX_LINES - 1)) genes"
echo "=============================================="
