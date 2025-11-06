#!/bin/bash
#SBATCH --job-name=trimmomatic
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=20G
#SBATCH --time=10:00:00
#SBATCH --partition=standard
#SBATCH --output=../logs/03_trimmomatic_%j.out
#SBATCH --error=../logs/03_trimmomatic_%j.err

# Adapter trimming and quality filtering with Trimmomatic
# Processes all 42 paired-end samples sequentially

module load trimmomatic/0.39

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
RAW_DIR=${BASE_DIR}/01.RawData
TRIMMED_DIR=${BASE_DIR}/02.Trimmed
mkdir -p ${TRIMMED_DIR}

# Trimmomatic adapter file for NovaSeq (uses NextSeq/NovaSeq adapters)
# NovaSeq uses same adapters as NextSeq - check both possibilities
ADAPTER_DIR=/opt/apps/trimmomatic/0.39/adapters
if [[ -f ${ADAPTER_DIR}/NextSeq-PE.fa ]]; then
    ADAPTERS=${ADAPTER_DIR}/NextSeq-PE.fa
elif [[ -f ${ADAPTER_DIR}/TruSeq3-PE.fa ]]; then
    ADAPTERS=${ADAPTER_DIR}/TruSeq3-PE.fa
else
    echo "ERROR: Could not find adapter file!"
    echo "Checked: ${ADAPTER_DIR}/NextSeq-PE.fa and TruSeq3-PE.fa"
    exit 1
fi

echo "=========================================="
echo "Trimmomatic - Adapter Trimming & Quality Filtering"
echo "=========================================="
echo "Raw data directory: ${RAW_DIR}"
echo "Output directory: ${TRIMMED_DIR}"
echo "Adapter file: ${ADAPTERS}"
echo "Threads: 10"
echo "=========================================="
echo ""

# Get list of all sample directories
SAMPLES=($(ls -d ${RAW_DIR}/*/ | xargs -n 1 basename))
TOTAL=${#SAMPLES[@]}

echo "Found ${TOTAL} samples to process"
echo ""

# Process each sample
COUNT=0
for SAMPLE in "${SAMPLES[@]}"; do
    COUNT=$((COUNT + 1))
    echo "----------------------------------------"
    echo "Processing sample ${COUNT}/${TOTAL}: ${SAMPLE}"
    echo "----------------------------------------"
    
    # Define input files
    R1=${RAW_DIR}/${SAMPLE}/${SAMPLE}_1.fq.gz
    R2=${RAW_DIR}/${SAMPLE}/${SAMPLE}_2.fq.gz
    
    # Define output files
    R1_PAIRED=${TRIMMED_DIR}/${SAMPLE}_1_paired.fq.gz
    R1_UNPAIRED=${TRIMMED_DIR}/${SAMPLE}_1_unpaired.fq.gz
    R2_PAIRED=${TRIMMED_DIR}/${SAMPLE}_2_paired.fq.gz
    R2_UNPAIRED=${TRIMMED_DIR}/${SAMPLE}_2_unpaired.fq.gz
    
    # Check input files exist
    if [[ ! -f ${R1} ]] || [[ ! -f ${R2} ]]; then
        echo "ERROR: Input files not found for ${SAMPLE}"
        echo "  Expected: ${R1}"
        echo "  Expected: ${R2}"
        continue
    fi
    
    # Run Trimmomatic in paired-end mode
    echo "Running Trimmomatic..."
    trimmomatic PE -threads 10 \
        ${R1} ${R2} \
        ${R1_PAIRED} ${R1_UNPAIRED} \
        ${R2_PAIRED} ${R2_UNPAIRED} \
        ILLUMINACLIP:${ADAPTERS}:2:30:10 \
        SLIDINGWINDOW:4:20 \
        MINLEN:36
    
    # Remove unpaired reads (as specified - discard unpaired)
    rm -f ${R1_UNPAIRED} ${R2_UNPAIRED}
    
    echo "✓ Completed ${SAMPLE}"
    echo ""
done

echo "=========================================="
echo "Trimmomatic complete!"
echo "=========================================="
echo "Processed ${TOTAL} samples"
echo "Trimmed reads saved to: ${TRIMMED_DIR}"
echo ""
echo "Output files (per sample):"
echo "  *_1_paired.fq.gz - Forward reads (trimmed, paired)"
echo "  *_2_paired.fq.gz - Reverse reads (trimmed, paired)"
echo ""
echo "Next step: FastQC on trimmed reads"
echo ""
