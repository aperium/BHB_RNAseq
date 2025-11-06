#!/bin/bash
#SBATCH --job-name=featureCounts
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=40G
#SBATCH --time=2:30:00
#SBATCH --partition=standard
#SBATCH --output=../logs/06_featureCounts_%j.out
#SBATCH --error=../logs/06_featureCounts_%j.err

# Count reads per gene using featureCounts (subread package)
# Note: UVA HPC doesn't have subread as a module, so we'll use STAR's built-in counts
# and create the count matrix from STAR GeneCounts output

module load samtools

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
ALIGN_DIR=${BASE_DIR}/04.Alignment
COUNT_DIR=${BASE_DIR}/05.Counts
mkdir -p ${COUNT_DIR}

echo "Extracting gene counts from STAR output..."

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

# Copy individual count files
for SAMPLE in "${SAMPLES[@]}"; do
    COUNT_FILE=${ALIGN_DIR}/${SAMPLE}/${SAMPLE}_ReadsPerGene.out.tab
    if [ -f "$COUNT_FILE" ]; then
        cp ${COUNT_FILE} ${COUNT_DIR}/${SAMPLE}_counts.txt
        echo "Copied counts for ${SAMPLE}"
    else
        echo "WARNING: Count file not found for ${SAMPLE}"
    fi
done

# Create combined count matrix (unstranded - column 2)
# Column 1: gene ID
# Column 2: counts for unstranded
# Column 3: counts for stranded (forward)
# Column 4: counts for stranded (reverse)

echo "Creating combined count matrix..."

# Get gene names from first sample
FIRST_SAMPLE=${SAMPLES[0]}
awk 'NR>4 {print $1}' ${COUNT_DIR}/${FIRST_SAMPLE}_counts.txt > ${COUNT_DIR}/gene_ids.tmp

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

echo "Count matrix created successfully!"
echo "Output: ${COUNT_DIR}/counts_matrix_unstranded.txt"
echo "Dimensions:"
wc -l ${COUNT_DIR}/counts_matrix_unstranded.txt
head -n 1 ${COUNT_DIR}/counts_matrix_unstranded.txt | awk '{print NF " columns"}'
