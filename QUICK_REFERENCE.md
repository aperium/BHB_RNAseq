# BHB RNA-seq Pipeline - Quick Reference Card

**GitHub Repository**: https://github.com/aperium/BHB_RNAseq

## Initial Setup (One Time)

### Option 1: Clone from GitHub (Recommended)
```bash
# SSH to HPC
ssh $USER@login.hpc.virginia.edu
cd /scratch/$USER/BHB_complete

# Clone repository
git clone https://github.com/aperium/BHB_RNAseq.git

# Create logs directory
mkdir -p logs
```

### Option 2: Transfer from Local Machine
```bash
# On local machine
cd /path/to/your/local/workspace
rsync -avz --exclude='.git' --exclude='SETUP_INSTRUCTIONS_files' \
    BHB_RNAseq/ $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/BHB_RNAseq/

# On HPC - create directories
ssh $USER@login.hpc.virginia.edu
cd /scratch/$USER/BHB_complete
mkdir -p logs
```

### Setup Conda Environment (One Time)
```bash
# On HPC
module load miniforge/24.11.3-py3.12
conda create -y -n rnaseq_r -c conda-forge -c bioconda \
    r-base r-deseq2 r-ggplot2 r-pheatmap r-dplyr \
    r-rcolorbrewer bioconductor-enhancedvolcano
```

## Julia QC Validation (NEW - Phase 1!)

**Setup (one-time on login node):**
```bash
bash scripts/setup_julia_env.sh
```

**Run QC after featureCounts:**
```bash
sbatch 09.5_validate_counts_qc.slurm  # ~1-2 min
```

**View results:**
```bash
cat /scratch/$USER/BHB_complete/05.Counts/julia_qc_report.txt
```

**What it does:**
- ✓ Validates all 42 STAR count files
- ✓ Checks combined count matrix
- ✓ Cross-validates individual files vs matrix
- ✓ Calculates ERCC statistics
- ✓ Identifies outliers and issues

See `JULIA_PHASE1_README.md` for full documentation.

---

## Running the Pipeline

```bash
# SSH to HPC
ssh $USER@login.hpc.virginia.edu
cd /scratch/$USER/BHB_complete/BHB_RNAseq

# Run entire pipeline automatically (recommended)
bash run_full_pipeline.sh

# OR run steps individually:
sbatch 00_download_reference.slurm     # ~30 min
sbatch 01_fastqc_raw.slurm             # ~2-3 hours
sbatch 02_multiqc_raw.slurm            # ~5 min
sbatch 03_trimmomatic.slurm            # ~1-2 hours (42 parallel jobs)
sbatch 04_fastqc_trimmed.slurm         # ~2-3 hours
sbatch 05_multiqc_trimmed.slurm        # ~5 min
sbatch 06_build_star_index.slurm      # ~15 min (parallel with QC)
sbatch 07_star_align.slurm             # ~2-3 hours (42 parallel jobs)
sbatch 08_multiqc_alignment.slurm     # ~5 min
sbatch 09_featureCounts.slurm         # ~10 min
sbatch 09.5_validate_counts_qc.slurm  # ~1-2 min (Julia QC - optional)
sbatch 10_run_deseq2.slurm            # ~1 hour
```

## Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# Watch jobs in real-time
watch -n 60 'squeue -u $USER'

# View specific job log
tail -f ../logs/04_star_align_JOBID_ARRAYID.out

# Check completed jobs
sacct -u $USER --starttime=2025-11-05

# Cancel a job
scancel JOBID

# Cancel all your jobs
scancel -u $USER
```

## Directory Structure

```
/scratch/$USER/BHB_complete/
├── BHB_RNAseq/          ← Work from here (scripts)
├── logs/                ← SLURM job logs
├── 01.RawData/          ← Raw FASTQ files
├── 02.TrimmedData/      ← Trimmed FASTQ files
├── 00.Reference/        ← Genome + ERCC references
├── 03.FastQC_raw/       ← QC reports (raw reads)
├── 04.Alignment/        ← BAM files
├── 05.Counts/           ← Count matrix
└── 06.DESeq2_results/   ← Final results + ERCC QC
```

## Key Output Files

### Quality Control
- `../03.FastQC_raw/multiqc_raw_report.html` - Raw read quality
- `../02.TrimmedData/fastqc/multiqc_trimmed_report.html` - Trimmed read quality
- `../04.Alignment/multiqc_alignment_report.html` - Alignment stats

### ERCC Spike-in QC
- `../06.DESeq2_results/ERCC_alignment_stats.csv` - ERCC metrics
- `../06.DESeq2_results/ERCC_percentage_by_sample.pdf` - ERCC %
- `../06.DESeq2_results/size_factor_comparison.pdf` - Normalization

### Differential Expression
- `../06.DESeq2_results/DE_summary.csv` - All comparisons summary
- `../06.DESeq2_results/DESeq2_*.csv` - Individual results
- `../06.DESeq2_results/PCA_plot.pdf` - Sample clustering
- `../06.DESeq2_results/volcano_*.pdf` - Volcano plots
- `../06.DESeq2_results/normalized_counts.csv` - ERCC-normalized counts

## Download Results to Local Machine

```bash
# On local machine
cd /path/to/your/local/workspace

# Quick - just final results
scp -r $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/06.DESeq2_results ./BHB_results/

# Complete - all outputs except raw data and BAMs
rsync -avz \
    --exclude='01.RawData' \
    --exclude='04.Alignment/*.bam' \
    $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/\
    ./BHB_results/
```

## Common SLURM Commands

```bash
# Job status
squeue -u $USER# Your jobs
squeue -j JOBID               # Specific job
squeue -j JOBID --array       # Array job tasks

# Job details
scontrol show job JOBID

# Job history
sacct -u $USER
sacct -j JOBID --format=JobID,JobName,State,Elapsed,MaxRSS

# Cancel jobs
scancel JOBID                 # Cancel one job
scancel -u $USER.             # Cancel all your jobs
scancel -u $USER-t PENDING    # Cancel pending jobs only

# Resource usage
allocations
```

## ERCC Quality Checkpoints

After pipeline completion, verify:

1. ✅ **ERCC %**: 1-5% per sample (`ERCC_alignment_stats.csv`)
2. ✅ **ERCC CV**: <20% across samples (`ERCC_percentage_by_sample.pdf`)
3. ✅ **ERCC detected**: 80-92 transcripts (`ERCC_counts.csv`)
4. ✅ **No outliers**: Check bar plot for unusual samples
5. ✅ **Size factors**: Review comparison plot

⚠️ If ERCC QC fails, see `ERCC_SPIKE_IN_GUIDE.md` for troubleshooting.

## Experimental Design

- **42 samples** (paired-end RNA-seq)
- **2 growth phases**: log, stationary
- **7 treatments**: N, B, L, M, C, BM, LM
- **3 biological replicates** per condition
- **ERCC92 Mix 1** spike-ins for normalization

## Main Comparisons (DESeq2)

**Stationary Phase:**
- BHB vs nonrestricted
- acac vs nonrestricted
- mes vs nonrestricted
- control vs nonrestricted

**Log Phase:**
- BHB vs nonrestricted
- acac vs nonrestricted
- mes vs nonrestricted
- control vs nonrestricted

**Phase Effects:**
- Stationary vs log (in each treatment)

## Troubleshooting

### Job fails immediately
```bash
# Check error log
cat ../logs/SCRIPTNAME_JOBID.err

# Common issues:
# - Module not loaded
# - File paths incorrect
# - Insufficient resources
```

### Array job has failed tasks
```bash
# Check which tasks failed
sacct -j JOBID --format=JobID,State

# Resubmit specific tasks
sbatch --array=5,12,23 04_star_align.slurm
```

### DESeq2 fails
```bash
# Verify conda environment
module load miniforge/24.11.3-py3.12
conda activate rnaseq_r
R
# In R: library(DESeq2)

# If packages missing, reinstall
conda env remove -n rnaseq_r
# Then recreate (see setup section above)
```

### Low alignment rates
- Check FastQC reports for remaining adapter contamination
- Review Trimmomatic logs for errors
- Verify correct reference genome
- Compare raw vs trimmed read quality in MultiQC reports

## Getting Help

- **Pipeline documentation**: `README_pipeline.md`
- **Detailed setup**: `SETUP_INSTRUCTIONS.md`
- **ERCC interpretation**: `ERCC_SPIKE_IN_GUIDE.md`
- **UVA HPC support**: hpc-support@virginia.edu
- **UVA HPC docs**: https://www.rc.virginia.edu/userinfo/hpc/

## Expected Timeline

| Step | Time | Parallelized |
|------|------|--------------|
| 0. Download reference | 30 min | No |
| 1. FastQC raw | 2-3 hours | Partial |
| 2. MultiQC raw | 5 min | No |
| 3. STAR index | 15 min | No |
| 4. STAR align | 2-3 hours | **Yes (42 jobs)** |
| 5. MultiQC align | 5 min | No |
| 6. featureCounts | 10 min | No |
| 7. DESeq2 | 1 hour | No |
| **Total** | **6-8 hours** | With parallelization |

---

**Last Updated**: 2025-11-05  
**Pipeline Version**: 1.0 with ERCC92 spike-ins  
**Contact**: hjs8zu@virginia.edu
