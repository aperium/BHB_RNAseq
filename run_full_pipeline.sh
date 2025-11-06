#!/bin/bash
# Master script to submit entire BHB RNA-seq pipeline with job dependencies
# Run from: /scratch/$USER/BHB_complete/BHB_RNAseq
# Usage: bash run_full_pipeline.sh

echo "=========================================="
echo "BHB RNA-seq Pipeline - Full Submission"
echo "=========================================="
echo ""
echo "This will submit all 11 pipeline steps with job dependencies."
echo "Jobs will automatically run in sequence as dependencies complete."
echo ""
echo "Pipeline steps:"
echo "  0. Download reference genome + ERCC"
echo "  1. FastQC on raw reads"
echo "  2. MultiQC raw reads"
echo "  3. Trimmomatic quality trimming"
echo "  4. FastQC on trimmed reads"
echo "  5. MultiQC trimmed reads"
echo "  6. Build STAR index"
echo "  7. STAR alignment (42 samples in parallel)"
echo "  8. MultiQC alignment stats"
echo "  9. Generate count matrix"
echo " 10. DESeq2 differential expression"
echo ""

# Check we're in the right directory
if [[ ! -f "00_download_reference.slurm" ]]; then
    echo "ERROR: Must run from BHB_RNAseq directory!"
    echo "cd /scratch/\$USER/BHB_complete/BHB_RNAseq"
    exit 1
fi

# Check conda environment exists for DESeq2
module load miniforge/24.11.3-py3.12 2>/dev/null
if ! conda env list | grep -q "rnaseq_r"; then
    echo "WARNING: Conda environment 'rnaseq_r' not found!"
    echo "Step 7 (DESeq2) will fail without it."
    echo ""
    echo "To create the environment:"
    echo "  module load miniforge/24.11.3-py3.12"
    echo "  conda create -y -n rnaseq_r -c conda-forge -c bioconda \\"
    echo "      r-base r-deseq2 r-ggplot2 r-pheatmap r-dplyr \\"
    echo "      r-rcolorbrewer bioconductor-enhancedvolcano"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Submitting jobs..."
echo ""

# Submit Step 0: Download reference
JOB0=$(sbatch --parsable 00_download_reference.slurm)
echo "Step 0 (Download reference): Job ID $JOB0"

# Submit Step 1: FastQC (no dependency - can run immediately)
JOB1=$(sbatch --parsable 01_fastqc_raw.slurm)
echo "Step 1 (FastQC raw): Job ID $JOB1"

# Submit Step 2: MultiQC raw (depends on FastQC)
JOB2=$(sbatch --parsable --dependency=afterok:$JOB1 02_multiqc_raw.slurm)
echo "Step 2 (MultiQC raw): Job ID $JOB2 (waits for $JOB1)"

# Submit Step 3: Trimmomatic (depends on MultiQC raw completion, can start after QC verification)
JOB3=$(sbatch --parsable --dependency=afterok:$JOB2 03_trimmomatic.slurm)
echo "Step 3 (Trimmomatic): Job ID $JOB3 (waits for $JOB2) - 42 array tasks"

# Submit Step 4: FastQC trimmed (depends on Trimmomatic)
JOB4=$(sbatch --parsable --dependency=afterok:$JOB3 04_fastqc_trimmed.slurm)
echo "Step 4 (FastQC trimmed): Job ID $JOB4 (waits for $JOB3)"

# Submit Step 5: MultiQC trimmed (depends on FastQC trimmed)
JOB5=$(sbatch --parsable --dependency=afterok:$JOB4 05_multiqc_trimmed.slurm)
echo "Step 5 (MultiQC trimmed): Job ID $JOB5 (waits for $JOB4)"

# Submit Step 6: Build STAR index (depends on reference download, can run in parallel with QC/trimming)
JOB6=$(sbatch --parsable --dependency=afterok:$JOB0 06_build_star_index.slurm)
echo "Step 6 (STAR index): Job ID $JOB6 (waits for $JOB0)"

# Submit Step 7: STAR alignment (depends on STAR index AND trimmed reads)
JOB7=$(sbatch --parsable --dependency=afterok:$JOB6,afterok:$JOB3 07_star_align.slurm)
echo "Step 7 (STAR align): Job ID $JOB7 (waits for $JOB6 and $JOB3) - 42 array tasks"

# Submit Step 8: MultiQC alignment (depends on STAR alignment)
JOB8=$(sbatch --parsable --dependency=afterok:$JOB7 08_multiqc_alignment.slurm)
echo "Step 8 (MultiQC align): Job ID $JOB8 (waits for $JOB7)"

# Submit Step 9: featureCounts (depends on STAR alignment)
JOB9=$(sbatch --parsable --dependency=afterok:$JOB7 09_featureCounts.slurm)
echo "Step 9 (featureCounts): Job ID $JOB9 (waits for $JOB7)"

# Submit Step 10: DESeq2 (depends on counts)
JOB10=$(sbatch --parsable --dependency=afterok:$JOB9 10_run_deseq2.slurm)
echo "Step 10 (DESeq2): Job ID $JOB10 (waits for $JOB9)"

echo ""
echo "=========================================="
echo "All jobs submitted successfully!"
echo "=========================================="
echo ""
echo "Job dependency chain:"
echo "  QC Track: FastQC raw ($JOB1) → MultiQC raw ($JOB2) → Trimmomatic ($JOB3) → FastQC trimmed ($JOB4) → MultiQC trimmed ($JOB5)"
echo "  Index Track: Download ref ($JOB0) → STAR index ($JOB6)"
echo "  Main Track: STAR align ($JOB7, waits for $JOB6+$JOB3) → featureCounts ($JOB9) → DESeq2 ($JOB10)"
echo "  QC Track: Alignment ($JOB7) → MultiQC align ($JOB8)"
echo ""
echo "Monitor progress:"
echo "  squeue -u \$USER"
echo "  watch -n 60 'squeue -u \$USER'"
echo ""
echo "View logs:"
echo "  cd /scratch/\$USER/BHB_complete/logs"
echo "  tail -f 03_trimmomatic_${JOB3}_*.out"
echo "  tail -f 07_star_align_${JOB7}_*.out"
echo ""
echo "Expected total runtime: 8-10 hours (includes trimming)"
echo ""
