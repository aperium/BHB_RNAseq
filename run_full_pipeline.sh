#!/bin/bash
# Master script to submit entire BHB RNA-seq pipeline with job dependencies
# Run from: /scratch/$USER/BHB_complete/BHB_RNAseq
# Usage: bash run_full_pipeline.sh

echo "=========================================="
echo "BHB RNA-seq Pipeline - Full Submission"
echo "=========================================="
echo ""
echo "This will submit all 8 pipeline steps with job dependencies."
echo "Jobs will automatically run in sequence as dependencies complete."
echo ""
echo "Pipeline steps:"
echo "  0. Download reference genome + ERCC"
echo "  1. FastQC on raw reads"
echo "  2. MultiQC raw reads"
echo "  3. Build STAR index"
echo "  4. STAR alignment (42 samples in parallel)"
echo "  5. MultiQC alignment stats"
echo "  6. Generate count matrix"
echo "  7. DESeq2 differential expression"
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

# Submit Step 3: Build STAR index (depends on reference download)
JOB3=$(sbatch --parsable --dependency=afterok:$JOB0 03_build_star_index.slurm)
echo "Step 3 (STAR index): Job ID $JOB3 (waits for $JOB0)"

# Submit Step 4: STAR alignment (depends on STAR index)
JOB4=$(sbatch --parsable --dependency=afterok:$JOB3 04_star_align.slurm)
echo "Step 4 (STAR align): Job ID $JOB4 (waits for $JOB3) - 42 array tasks"

# Submit Step 5: MultiQC alignment (depends on STAR alignment)
JOB5=$(sbatch --parsable --dependency=afterok:$JOB4 05_multiqc_alignment.slurm)
echo "Step 5 (MultiQC align): Job ID $JOB5 (waits for $JOB4)"

# Submit Step 6: featureCounts (depends on STAR alignment)
JOB6=$(sbatch --parsable --dependency=afterok:$JOB4 06_featureCounts.slurm)
echo "Step 6 (featureCounts): Job ID $JOB6 (waits for $JOB4)"

# Submit Step 7: DESeq2 (depends on counts)
JOB7=$(sbatch --parsable --dependency=afterok:$JOB6 07_run_deseq2.slurm)
echo "Step 7 (DESeq2): Job ID $JOB7 (waits for $JOB6)"

echo ""
echo "=========================================="
echo "All jobs submitted successfully!"
echo "=========================================="
echo ""
echo "Job dependency chain:"
echo "  Download ref ($JOB0) → STAR index ($JOB3) → Alignment ($JOB4) → featureCounts ($JOB6) → DESeq2 ($JOB7)"
echo "  FastQC ($JOB1) → MultiQC raw ($JOB2)"
echo "  Alignment ($JOB4) → MultiQC align ($JOB5)"
echo ""
echo "Monitor progress:"
echo "  squeue -u \$USER"
echo "  watch -n 60 'squeue -u \$USER'"
echo ""
echo "View logs:"
echo "  cd /scratch/\$USER/BHB_complete/logs"
echo "  tail -f 04_star_align_${JOB4}_*.out"
echo ""
echo "Expected total runtime: 6-8 hours"
echo ""
