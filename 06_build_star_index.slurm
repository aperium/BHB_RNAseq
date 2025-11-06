#!/bin/bash
#SBATCH --job-name=star_index
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=2:00:00
#SBATCH --partition=standard
#SBATCH --account=${HPC_ACCOUNT:-$USER}
#SBATCH --output=../logs/03_star_index_%j.out
#SBATCH --error=../logs/03_star_index_%j.err

# Build STAR genome index for S. cerevisiae + ERCC92 spike-ins

module load star/2.7.11b

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
REF_DIR=${BASE_DIR}/00.Reference
INDEX_DIR=${BASE_DIR}/00.Reference/STAR_index
mkdir -p ${INDEX_DIR}

# Use combined reference files (yeast + ERCC)
GENOME_FA=${REF_DIR}/combined_genome.fa
GTF=${REF_DIR}/combined_annotation.gtf

echo "Building STAR index with yeast + ERCC92 references..."
echo "Genome: ${GENOME_FA}"
echo "GTF: ${GTF}"
echo "Output: ${INDEX_DIR}"

# Verify files exist
if [ ! -f "${GENOME_FA}" ]; then
    echo "ERROR: Combined genome FASTA not found!"
    exit 1
fi

if [ ! -f "${GTF}" ]; then
    echo "ERROR: Combined GTF not found!"
    exit 1
fi

# Build STAR index
# --genomeSAindexNbases 10 is appropriate for small genomes like yeast (~12 Mb)
# Formula: min(14, log2(GenomeLength)/2 - 1)
# For yeast: log2(12000000)/2 - 1 ≈ 10.5, so use 10
# ERCC adds minimal size, so same parameter is appropriate

STAR --runMode genomeGenerate \
    --runThreadN 16 \
    --genomeDir ${INDEX_DIR} \
    --genomeFastaFiles ${GENOME_FA} \
    --sjdbGTFfile ${GTF} \
    --sjdbOverhang 149 \
    --genomeSAindexNbases 10

echo ""
echo "STAR index build complete!"
echo "Index includes:"
echo "  - S. cerevisiae genome (R64-1-1)"
echo "  - ERCC92 spike-in sequences"
echo ""
echo "Reads will now align to both yeast genes and ERCC controls."
