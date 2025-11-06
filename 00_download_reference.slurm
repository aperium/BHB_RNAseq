#!/bin/bash
#SBATCH --job-name=download_ref
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=2:00:00
#SBATCH --partition=standard
#SBATCH --account=${HPC_ACCOUNT:-$USER}
#SBATCH --output=../logs/00_download_ref_%j.out
#SBATCH --error=../logs/00_download_ref_%j.err

# Download S. cerevisiae reference genome and annotation
# Plus ERCC92 spike-in references
# Ensembl Release 113

# Set up directories
BASE_DIR=/scratch/${USER}/BHB_complete
SCRIPT_DIR=${BASE_DIR}/BHB_RNAseq
REF_DIR=${BASE_DIR}/00.Reference
mkdir -p ${REF_DIR}
mkdir -p ${BASE_DIR}/logs

cd ${REF_DIR}

# ========== Download S. cerevisiae reference ==========
echo "Downloading yeast reference genome..."
wget -c http://ftp.ensembl.org/pub/release-113/fasta/saccharomyces_cerevisiae/dna/Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa.gz

echo "Downloading yeast gene annotation..."
wget -c http://ftp.ensembl.org/pub/release-113/gtf/saccharomyces_cerevisiae/Saccharomyces_cerevisiae.R64-1-1.113.gtf.gz

# Decompress yeast files
echo "Decompressing yeast files..."
gunzip Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa.gz
gunzip Saccharomyces_cerevisiae.R64-1-1.113.gtf.gz

# ========== Download ERCC92 spike-in references ==========
echo "Downloading ERCC92 spike-in sequences..."
# ERCC sequences from Thermo Fisher / Life Technologies
wget -c https://assets.thermofisher.com/TFS-Assets/LSG/manuals/ERCC92.zip

# Unzip ERCC files
unzip -o ERCC92.zip

# The zip contains ERCC92.fa and ERCC92.gtf
# Check if files exist, if not create them from common sources
if [ ! -f "ERCC92.fa" ]; then
    echo "Downloading ERCC FASTA from alternative source..."
    wget -O ERCC92.fa "https://www-s.nist.gov/srmors/certificates/documents/SRM2374_Sequence_v1.FASTA"
fi

if [ ! -f "ERCC92.gtf" ]; then
    echo "Creating ERCC GTF annotation..."
    # If GTF doesn't exist, we'll create a basic one from the FASTA
    # This creates gene and transcript features for each ERCC
    awk '/^>/ {
        if (seqname) {
            print seqname "\tERCC\tgene\t1\t" seqlen "\t.\t+\t.\tgene_id \"" seqname "\"; gene_name \"" seqname "\"; gene_biotype \"spike_in\";"
            print seqname "\tERCC\ttranscript\t1\t" seqlen "\t.\t+\t.\tgene_id \"" seqname "\"; transcript_id \"" seqname "\"; gene_name \"" seqname "\"; gene_biotype \"spike_in\";"
            print seqname "\tERCC\texon\t1\t" seqlen "\t.\t+\t.\tgene_id \"" seqname "\"; transcript_id \"" seqname "\"; exon_number \"1\"; gene_name \"" seqname "\"; gene_biotype \"spike_in\";"
        }
        seqname = substr($1, 2); seqlen=0; next
    } 
    {seqlen += length($0)} 
    END {
        if (seqname) {
            print seqname "\tERCC\tgene\t1\t" seqlen "\t.\t+\t.\tgene_id \"" seqname "\"; gene_name \"" seqname "\"; gene_biotype \"spike_in\";"
            print seqname "\tERCC\ttranscript\t1\t" seqlen "\t.\t+\t.\tgene_id \"" seqname "\"; transcript_id \"" seqname "\"; gene_name \"" seqname "\"; gene_biotype \"spike_in\";"
            print seqname "\tERCC\texon\t1\t" seqlen "\t.\t+\t.\tgene_id \"" seqname "\"; transcript_id \"" seqname "\"; exon_number \"1\"; gene_name \"" seqname "\"; gene_biotype \"spike_in\";"
        }
    }' ERCC92.fa > ERCC92.gtf
fi

# ========== Combine reference files ==========
echo "Combining yeast and ERCC reference files..."

# Combine FASTA files
cat Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa ERCC92.fa > combined_genome.fa

# Combine GTF files
cat Saccharomyces_cerevisiae.R64-1-1.113.gtf ERCC92.gtf > combined_annotation.gtf

echo "Combined reference files created:"
echo "  - combined_genome.fa (yeast + ERCC)"
echo "  - combined_annotation.gtf (yeast + ERCC)"

# Create index for samtools
module load samtools/1.21
echo "Creating samtools index..."
samtools faidx combined_genome.fa

# Summary
echo ""
echo "========== Reference Download Summary =========="
echo "Yeast genome size:"
grep -v "^>" Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa | wc -c
echo "Yeast genes:"
grep -c "gene_id" Saccharomyces_cerevisiae.R64-1-1.113.gtf
echo ""
echo "ERCC sequences:"
grep -c "^>" ERCC92.fa
echo "ERCC features in GTF:"
grep -c "gene_id" ERCC92.gtf
echo ""
echo "Combined genome size:"
grep -v "^>" combined_genome.fa | wc -c
echo "Combined features in GTF:"
grep -c "gene_id" combined_annotation.gtf
echo "==============================================="

ls -lh *.fa *.gtf

echo ""
echo "Reference genome download and preparation complete!"
echo "Ready for STAR index building with combined reference."
