#!/bin/bash
# Master script to submit entire BHB RNA-seq pipeline with job dependencies
# Run from: /scratch/$USER/BHB_complete/BHB_RNAseq
# Usage: bash run_full_pipeline.sh [OPTIONS] [ACCOUNT]
#   --resume: Skip already-completed steps (based on output files)
#   ACCOUNT (optional): SLURM account to use (default: $USER)
#
# Examples:
#   bash run_full_pipeline.sh berglandlab
#   bash run_full_pipeline.sh --resume berglandlab
#   bash run_full_pipeline.sh berglandlab --resume

# Function to check if a step is complete based on expected output files
check_step_complete() {
    local step=$1
    case $step in
        0)  # Reference download - check for combined fasta
            [[ -f "../00.Reference/yeast_ercc_combined.fasta" ]] ;;
        1)  # FastQC raw - check for all 84 fastqc.zip files (42 samples × 2 files)
            [[ $(find ../03.FastQC_raw -name "*_fastqc.zip" 2>/dev/null | wc -l) -ge 84 ]] ;;
        2)  # MultiQC raw - check for report
            [[ -f "../03.FastQC_raw/multiqc_raw_report.html" ]] ;;
        3)  # Trimmomatic - check for all 84 paired output files (42 samples × 2 files)
            [[ $(find ../02.TrimmedData -name "*_paired.fastq.gz" 2>/dev/null | wc -l) -ge 84 ]] ;;
        4)  # FastQC trimmed - check for all 84 fastqc files on trimmed data
            [[ $(find ../02.TrimmedData/fastqc -name "*_fastqc.zip" 2>/dev/null | wc -l) -ge 84 ]] ;;
        5)  # MultiQC trimmed - check for report
            [[ -f "../02.TrimmedData/fastqc/multiqc_trimmed_report.html" ]] ;;
        6)  # STAR index - check for SAindex file
            [[ -f "../00.Reference/yeast_ercc_combined/SAindex" ]] ;;
        7)  # STAR alignment - check for all 42 BAM files
            [[ $(find ../04.STAR_alignment -name "*Aligned.sortedByCoord.out.bam" 2>/dev/null | wc -l) -ge 42 ]] ;;
        8)  # MultiQC alignment - check for report
            [[ -f "../04.STAR_alignment/multiqc_alignment_report.html" ]] ;;
        9)  # featureCounts - check for count matrix
            [[ -f "../05.Counts/counts_matrix_unstranded.txt" ]] ;;
        10) # DESeq2 - check for saved R object
            [[ -f "../06.DESeq2_results/dds.rds" ]] ;;
        *)  return 1 ;;
    esac
}

# Parse command-line arguments for --resume flag
RESUME=false
SLURM_ACCOUNT=""

for arg in "$@"; do
    if [[ "$arg" == "--resume" ]]; then
        RESUME=true
    else
        SLURM_ACCOUNT="$arg"
    fi
done

# Set default account if not provided
SLURM_ACCOUNT="${SLURM_ACCOUNT:-$USER}"

echo "=========================================="
echo "BHB RNA-seq Pipeline - Full Submission"
echo "=========================================="
echo ""
echo "SLURM Account: ${SLURM_ACCOUNT}"
if [[ "$RESUME" == true ]]; then
    echo "Resume Mode: ENABLED (skipping completed steps)"
else
    echo "Resume Mode: disabled (will submit all steps)"
fi
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
if [[ "$RESUME" == true ]] && check_step_complete 0; then
    echo "Step 0 (Download reference): ✓ ALREADY COMPLETE (skipping)"
    JOB0="completed"
else
    JOB0=$(sbatch --parsable --account=${SLURM_ACCOUNT} 00_download_reference.slurm)
    echo "Step 0 (Download reference): Job ID $JOB0"
fi

# Submit Step 1: FastQC (no dependency - can run immediately)
if [[ "$RESUME" == true ]] && check_step_complete 1; then
    echo "Step 1 (FastQC raw): ✓ ALREADY COMPLETE (skipping)"
    JOB1="completed"
else
    JOB1=$(sbatch --parsable --account=${SLURM_ACCOUNT} 01_fastqc_raw.slurm)
    echo "Step 1 (FastQC raw): Job ID $JOB1"
fi

# Submit Step 2: MultiQC raw (depends on FastQC)
if [[ "$RESUME" == true ]] && check_step_complete 2; then
    echo "Step 2 (MultiQC raw): ✓ ALREADY COMPLETE (skipping)"
    JOB2="completed"
else
    DEP_STRING=""
    [[ "$JOB1" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB1"
    JOB2=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 02_multiqc_raw.slurm)
    if [[ "$JOB1" == "completed" ]]; then
        echo "Step 2 (MultiQC raw): Job ID $JOB2"
    else
        echo "Step 2 (MultiQC raw): Job ID $JOB2 (waits for $JOB1)"
    fi
fi

# Submit Step 3: Trimmomatic (depends on MultiQC raw completion, can start after QC verification)
if [[ "$RESUME" == true ]] && check_step_complete 3; then
    echo "Step 3 (Trimmomatic): ✓ ALREADY COMPLETE (skipping)"
    JOB3="completed"
else
    DEP_STRING=""
    [[ "$JOB2" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB2"
    JOB3=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 03_trimmomatic.slurm)
    if [[ "$JOB2" == "completed" ]]; then
        echo "Step 3 (Trimmomatic): Job ID $JOB3 - 42 array tasks"
    else
        echo "Step 3 (Trimmomatic): Job ID $JOB3 (waits for $JOB2) - 42 array tasks"
    fi
fi

# Submit Step 4: FastQC trimmed (depends on Trimmomatic)
if [[ "$RESUME" == true ]] && check_step_complete 4; then
    echo "Step 4 (FastQC trimmed): ✓ ALREADY COMPLETE (skipping)"
    JOB4="completed"
else
    DEP_STRING=""
    [[ "$JOB3" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB3"
    JOB4=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 04_fastqc_trimmed.slurm)
    if [[ "$JOB3" == "completed" ]]; then
        echo "Step 4 (FastQC trimmed): Job ID $JOB4"
    else
        echo "Step 4 (FastQC trimmed): Job ID $JOB4 (waits for $JOB3)"
    fi
fi

# Submit Step 5: MultiQC trimmed (depends on FastQC trimmed)
if [[ "$RESUME" == true ]] && check_step_complete 5; then
    echo "Step 5 (MultiQC trimmed): ✓ ALREADY COMPLETE (skipping)"
    JOB5="completed"
else
    DEP_STRING=""
    [[ "$JOB4" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB4"
    JOB5=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 05_multiqc_trimmed.slurm)
    if [[ "$JOB4" == "completed" ]]; then
        echo "Step 5 (MultiQC trimmed): Job ID $JOB5"
    else
        echo "Step 5 (MultiQC trimmed): Job ID $JOB5 (waits for $JOB4)"
    fi
fi

# Submit Step 6: Build STAR index (depends on reference download, can run in parallel with QC/trimming)
if [[ "$RESUME" == true ]] && check_step_complete 6; then
    echo "Step 6 (STAR index): ✓ ALREADY COMPLETE (skipping)"
    JOB6="completed"
else
    DEP_STRING=""
    [[ "$JOB0" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB0"
    JOB6=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 06_build_star_index.slurm)
    if [[ "$JOB0" == "completed" ]]; then
        echo "Step 6 (STAR index): Job ID $JOB6"
    else
        echo "Step 6 (STAR index): Job ID $JOB6 (waits for $JOB0)"
    fi
fi

# Submit Step 7: STAR alignment (depends on STAR index AND trimmed reads)
if [[ "$RESUME" == true ]] && check_step_complete 7; then
    echo "Step 7 (STAR align): ✓ ALREADY COMPLETE (skipping)"
    JOB7="completed"
else
    DEP_STRING=""
    DEP_JOBS=()
    [[ "$JOB6" != "completed" ]] && DEP_JOBS+=("$JOB6")
    [[ "$JOB3" != "completed" ]] && DEP_JOBS+=("$JOB3")
    
    if [[ ${#DEP_JOBS[@]} -gt 0 ]]; then
        DEP_STRING="--dependency=afterok:$(IFS=:; echo "${DEP_JOBS[*]}" | sed 's/:/:afterok:/g')"
    fi
    
    JOB7=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 07_star_align.slurm)
    if [[ ${#DEP_JOBS[@]} -eq 0 ]]; then
        echo "Step 7 (STAR align): Job ID $JOB7 - 42 array tasks"
    else
        echo "Step 7 (STAR align): Job ID $JOB7 (waits for ${DEP_JOBS[*]}) - 42 array tasks"
    fi
fi

# Submit Step 8: MultiQC alignment (depends on STAR alignment)
if [[ "$RESUME" == true ]] && check_step_complete 8; then
    echo "Step 8 (MultiQC align): ✓ ALREADY COMPLETE (skipping)"
    JOB8="completed"
else
    DEP_STRING=""
    [[ "$JOB7" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB7"
    JOB8=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 08_multiqc_alignment.slurm)
    if [[ "$JOB7" == "completed" ]]; then
        echo "Step 8 (MultiQC align): Job ID $JOB8"
    else
        echo "Step 8 (MultiQC align): Job ID $JOB8 (waits for $JOB7)"
    fi
fi

# Submit Step 9: featureCounts (depends on STAR alignment)
if [[ "$RESUME" == true ]] && check_step_complete 9; then
    echo "Step 9 (featureCounts): ✓ ALREADY COMPLETE (skipping)"
    JOB9="completed"
else
    DEP_STRING=""
    [[ "$JOB7" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB7"
    JOB9=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 09_featureCounts.slurm)
    if [[ "$JOB7" == "completed" ]]; then
        echo "Step 9 (featureCounts): Job ID $JOB9"
    else
        echo "Step 9 (featureCounts): Job ID $JOB9 (waits for $JOB7)"
    fi
fi

# Submit Step 10: DESeq2 (depends on counts)
if [[ "$RESUME" == true ]] && check_step_complete 10; then
    echo "Step 10 (DESeq2): ✓ ALREADY COMPLETE (skipping)"
    JOB10="completed"
else
    DEP_STRING=""
    [[ "$JOB9" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB9"
    JOB10=$(sbatch --parsable --account=${SLURM_ACCOUNT} $DEP_STRING 10_run_deseq2.slurm)
    if [[ "$JOB9" == "completed" ]]; then
        echo "Step 10 (DESeq2): Job ID $JOB10"
    else
        echo "Step 10 (DESeq2): Job ID $JOB10 (waits for $JOB9)"
    fi
fi

echo ""
echo "=========================================="
echo "All jobs submitted successfully!"
echo "=========================================="
echo ""

# Count how many jobs were skipped vs submitted
SKIPPED=0
SUBMITTED=0
for job in "$JOB0" "$JOB1" "$JOB2" "$JOB3" "$JOB4" "$JOB5" "$JOB6" "$JOB7" "$JOB8" "$JOB9" "$JOB10"; do
    if [[ "$job" == "completed" ]]; then
        ((SKIPPED++))
    else
        ((SUBMITTED++))
    fi
done

if [[ $SKIPPED -gt 0 ]]; then
    echo "Resume summary: $SKIPPED steps skipped (already complete), $SUBMITTED new jobs submitted"
    echo ""
fi

echo "Job dependency chain:"
echo "  QC Track: FastQC raw ($JOB1) → MultiQC raw ($JOB2) → Trimmomatic ($JOB3) → FastQC trimmed ($JOB4) → MultiQC trimmed ($JOB5)"
echo "  Index Track: Download ref ($JOB0) → STAR index ($JOB6)"
echo "  Main Track: STAR align ($JOB7, waits for $JOB6+$JOB3) → featureCounts ($JOB9) → DESeq2 ($JOB10)"
echo "  QC Track: Alignment ($JOB7) → MultiQC align ($JOB8)"
echo ""
echo "  (Note: 'completed' = skipped because already done)"
echo ""

# Only show monitoring commands if we actually submitted jobs
if [[ $SUBMITTED -gt 0 ]]; then
    echo "Monitor progress:"
    echo "  squeue -u \$USER"
    echo "  watch -n 60 'squeue -u \$USER'"
    echo ""
    
    # Find first active job for log tailing example
    FIRST_ACTIVE=""
    for job in "$JOB3" "$JOB7"; do
        if [[ "$job" != "completed" ]] && [[ -z "$FIRST_ACTIVE" ]]; then
            FIRST_ACTIVE="$job"
            break
        fi
    done
    
    if [[ -n "$FIRST_ACTIVE" ]]; then
        echo "View logs (example):"
        echo "  cd /scratch/\$USER/BHB_complete/logs"
        if [[ "$JOB3" != "completed" ]]; then
            echo "  tail -f 03_trimmomatic_${JOB3}_*.out"
        fi
        if [[ "$JOB7" != "completed" ]]; then
            echo "  tail -f 07_star_align_${JOB7}_*.out"
        fi
        echo ""
    fi
    
    echo "Expected total runtime: 8-10 hours (includes trimming)"
else
    echo "All pipeline steps already complete! No new jobs submitted."
fi
echo ""
