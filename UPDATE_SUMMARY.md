# Pipeline Update Summary

## Latest Update: Enforced QC Gating with Resume Support

**Date**: November 6, 2025  
**Update**: Added mandatory quality control gating step (5.5) with full resume functionality

### New Feature: QC Gating Step (Step 5.5)

The pipeline now includes a **mandatory quality control check** between trimming QC and alignment:

**What it does:**
- Validates trimming quality using MultiQC metrics
- **Blocks downstream steps** (STAR alignment, featureCounts, DESeq2) if quality is insufficient
- Creates marker files to track QC pass/fail status
- Integrates with checkpoint/resume system

**Quality Criteria:**
- ≥95% of samples must pass all QC checks:
  - Mean quality score ≥30
  - ≥90% bases above Q30
  - Adapter content <5%
  - Duplication rate <50%

**How it works:**
```bash
# Automatic in full pipeline
bash run_full_pipeline.sh berglandlab

# Step 5.5 runs automatically after Step 5 (MultiQC trimmed)
# If QC PASSES: Creates qc_validation_passed.marker → downstream continues
# If QC FAILS: Creates qc_validation_failed.marker → pipeline halts with error
```

**Resume behavior:**
- If QC already passed: Skips step 5.5, continues to alignment
- If QC previously failed: Reports failure, prevents downstream steps
- Manual override: `SKIP_QC_CHECK=1 bash run_full_pipeline.sh --resume berglandlab`

**Benefits:**
- ✅ Prevents wasting compute resources on poor-quality data
- ✅ Catches quality issues before expensive alignment steps
- ✅ Provides clear failure messages with actionable recommendations
- ✅ Integrated with resume system for seamless workflow
- ✅ Optional skip for troubleshooting or reanalysis

**Files created:**
- `../02.TrimmedData/fastqc/qc_validation_passed.marker` - QC passed, allow downstream
- `../02.TrimmedData/fastqc/qc_validation_failed.marker` - QC failed, block downstream

**New Script:**
- `05.5_check_trimming_quality.sh` - Automated QC validation script

**Updated Documentation:**
- `run_full_pipeline.sh` - Integrated QC gating into step sequence and resume logic
- Step numbering now explicitly includes step 5.5 in pipeline output
- `check_step_complete()` function detects QC marker files for proper resume behavior

---

## Previous Update: Checkpoint/Resume Functionality

**Date**: November 6, 2025  
**Update**: Added checkpoint/resume capability to `run_full_pipeline.sh`

### New Feature: Resume from Checkpoint

The master submission script now supports resuming from partial pipeline runs:

```bash
bash run_full_pipeline.sh --resume ${SLURM_ACCOUNT}
```

**How it works:**
- Checks for expected output files from each step
- Skips steps that have already completed successfully
- Only submits jobs for incomplete steps
- Maintains proper job dependencies between new and completed steps

**Benefits:**
- ✅ Saves compute time and SUs by not re-running expensive steps
- ✅ Easy recovery from pipeline interruptions or failures
- ✅ Test individual step changes without rerunning entire pipeline
- ✅ Flexible resumption - picks up exactly where you left off

**Checkpoint detection for each step:**
- Step 0: `../00.Reference/yeast_ercc_combined.fasta`
- Step 1: 84 FastQC zip files in `../03.FastQC_raw/`
- Step 2: `../03.FastQC_raw/multiqc_raw_report.html`
- Step 3: 84 paired trimmed FASTQ files in `../02.TrimmedData/`
- Step 4: 84 FastQC files for trimmed data
- Step 5: `../02.TrimmedData/fastqc/multiqc_trimmed_report.html`
- **Step 5.5: QC marker files (`qc_validation_passed.marker` or `qc_validation_failed.marker`)**
- Step 6: `../00.Reference/yeast_ercc_combined/SAindex`
- Step 7: 42 BAM files in `../04.STAR_alignment/`
- Step 8: `../04.STAR_alignment/multiqc_alignment_report.html`
- Step 9: `../05.Counts/counts_matrix_unstranded.txt`
- Step 10: `../06.DESeq2_results/dds.rds`

**Example usage:**
```bash
# First run gets interrupted after trimming completes
bash run_full_pipeline.sh berglandlab

# Later, resume from where it left off
bash run_full_pipeline.sh --resume berglandlab
# Output: "3 steps skipped (already complete), 8 new jobs submitted"
```

**Updated Documentation:**
- `README.md` - Added resume flag documentation
- `SETUP_INSTRUCTIONS.md` - Added detailed checkpoint information
- `run_full_pipeline.sh` - Enhanced with checkpoint detection logic

---

## Previous Update: Trimmomatic Quality Trimming Integration

**Date**: November 6, 2025  
**Update**: Added mandatory quality trimming step with Trimmomatic

### Changes

**Pipeline expanded from 8 to 11 steps** with the addition of:
- **Step 3**: Trimmomatic quality trimming (42 parallel jobs)
- **Step 4**: FastQC on trimmed reads
- **Step 5**: MultiQC on trimmed reads

**Rationale**: Implements best-practice approach with **two complete QC cycles**:
1. QC on raw reads (Steps 1-2) - identify quality issues
2. Quality trimming (Step 3) - remove adapters and low-quality bases
3. QC on trimmed reads (Steps 4-5) - **verify improvement before alignment**

#### Modified Scripts:

**07_star_align.slurm** (previously 04_star_align.slurm)
- Now uses **trimmed reads** from `/scratch/$USER/BHB_complete/02.TrimmedData/`
- Updated file patterns to match Trimmomatic paired output naming: `*_R1_paired.fastq.gz` / `*_R2_paired.fastq.gz`

**run_full_pipeline.sh**
- Updated to include three new Trimmomatic jobs with proper dependencies
- Jobs 6-10 renumbered (previously 3-7)
- Alignment now depends on both STAR index AND trimmed reads completion

#### New Scripts:

**03_trimmomatic.slurm**
- Platform: NovaSeq (uses NextSeq-PE.fa adapters)
- Quality filtering: SLIDINGWINDOW:4:20 (trim when avg quality drops below Q20 in 4bp window)
- Minimum length: MINLEN:36
- Discards unpaired reads (only keeps paired outputs for alignment)
- 42 parallel array jobs (one per sample)

**04_fastqc_trimmed.slurm**
- Runs FastQC on trimmed paired-end reads
- Outputs to `/scratch/$USER/BHB_complete/02.TrimmedData/fastqc/`

**05_multiqc_trimmed.slurm**
- Aggregates QC reports for trimmed reads
- Generates comparison report to verify quality improvement

#### New Directory:

```
02.TrimmedData/
├── *_R1_paired.fastq.gz     # Forward reads (trimmed, paired)
├── *_R2_paired.fastq.gz     # Reverse reads (trimmed, paired)
├── fastqc/                   # FastQC reports on trimmed reads
└── multiqc_trimmed_report.html
```

#### File Renumbering:

Scripts renumbered to accommodate new steps 3-5:
- `03_build_star_index.slurm` → `06_build_star_index.slurm`
- `04_star_align.slurm` → `07_star_align.slurm` (and modified)
- `05_multiqc_alignment.slurm` → `08_multiqc_alignment.slurm`
- `06_featureCounts.slurm` → `09_featureCounts.slurm`
- `07_deseq2_analysis.R` → `10_deseq2_analysis.R`
- `07_run_deseq2.slurm` → `10_run_deseq2.slurm`

#### Updated Documentation:

- `README.md` - Updated with 11-step pipeline structure
- `QUICK_REFERENCE.md` - Added Trimmomatic steps
- `SETUP_INSTRUCTIONS.md` - Updated module requirements and step numbering
- `run_full_pipeline.sh` - Now submits 11 steps with proper dependencies

**Expected Runtime**: Increased from ~6-8 hours to ~8-10 hours (includes trimming + additional QC)

---

## Previous Update: ERCC92 Spike-in Integration

**Date**: November 5, 2025  
**Update**: ERCC92 spike-in integration + Directory reorganization

## Major Changes

### 1. ERCC92 Spike-in Integration

The pipeline now includes **ERCC92 Mix 1 spike-in controls** for improved normalization and quality control.

#### Modified Scripts:

**00_download_reference.slurm**
- Downloads ERCC92 FASTA and GTF files
- Combines yeast + ERCC references into unified files:
  - `combined_genome.fa`
  - `combined_annotation.gtf`
- Creates ERCC GTF annotation if not provided in download

**03_build_star_index.slurm**
- Builds STAR index with combined yeast + ERCC reference
- Allows simultaneous alignment to yeast genes and ERCC controls

**07_deseq2_analysis.R**
- Separates ERCC and yeast gene counts
- Calculates ERCC alignment statistics
- **Uses ERCC spike-ins for size factor normalization**
- Compares ERCC-based vs standard DESeq2 normalization
- Generates ERCC QC plots and metrics

#### New Output Files:

```
06.DESeq2_results/
├── ERCC_counts.csv                    # Raw ERCC counts (92 transcripts)
├── ERCC_alignment_stats.csv           # ERCC % per sample
├── ERCC_percentage_by_sample.pdf      # Bar plot of ERCC %
├── size_factor_comparison.csv         # ERCC vs standard normalization
└── size_factor_comparison.pdf         # Visualization of methods
```

### 2. Directory Reorganization

**New Structure:**
```
/scratch/$USER/BHB_complete/
├── BHB_RNAseq/              # Scripts directory (NEW)
│   ├── *.slurm              # All SLURM scripts
│   ├── *.R                  # R analysis scripts
│   ├── *.md                 # Documentation
│   └── experimental_design.csv
├── logs/                    # SLURM job logs (moved up)
├── 01.RawData/              # Raw FASTQ files
├── 00.Reference/            # Reference files + ERCC
├── 03.FastQC_raw/           # QC outputs
├── 04.Alignment/            # BAM files
├── 05.Counts/               # Count matrices
└── 06.DESeq2_results/       # Final results
```

**Benefits:**
- ✅ Cleaner separation: code vs data vs outputs
- ✅ Easier to sync scripts between local and HPC
- ✅ Logs in centralized location
- ✅ All scripts run from `BHB_RNAseq/` directory

#### Updated All SLURM Scripts:

Changed log output paths from:
```bash
#SBATCH --output=logs/script_%j.out
#SBATCH --error=logs/script_%j.err
```

To:
```bash
#SBATCH --output=../logs/script_%j.out
#SBATCH --error=../logs/script_%j.err
```

### 3. New Documentation

**ERCC_SPIKE_IN_GUIDE.md** (NEW)
- Comprehensive guide to ERCC spike-ins
- Explains normalization approach
- Interpretation of ERCC QC metrics
- Troubleshooting ERCC issues
- Quality control checkpoints

**QUICK_REFERENCE.md** (NEW)
- One-page command reference
- Common SLURM commands
- Monitoring and troubleshooting
- Expected timeline
- ERCC quality checkpoints

**run_full_pipeline.sh** (NEW)
- Master submission script
- Automatically submits all pipeline steps with dependencies
- Checks for conda environment
- Provides status updates

### 4. Updated Existing Documentation

**README_pipeline.md**
- Added ERCC information throughout
- Updated directory structure diagram
- Added "Quick Start" section with master script
- Updated output files section with ERCC files
- Added ERCC review to "Next Steps"

**SETUP_INSTRUCTIONS.md**
- Updated transfer instructions for new directory structure
- Changed all commands to run from `BHB_RNAseq/`
- Added ERCC Quality Control section
- Updated file download instructions
- Added ERCC quality criteria

## How to Use Updated Pipeline

### Transfer to HPC

```bash
# On local machine
cd /path/to/your/local/workspace
rsync -avz --exclude='.git' --exclude='SETUP_INSTRUCTIONS_files' \
    BHB_RNAseq/ $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/BHB_RNAseq/
```

### Run Pipeline

```bash
# On HPC
ssh $USER@login.hpc.virginia.edu
cd /scratch/$USER/BHB_complete/BHB_RNAseq

# Option 1: Automated (recommended)
bash run_full_pipeline.sh

# Option 2: Step-by-step
sbatch 00_download_reference.slurm
# ... etc
```

### Review ERCC Quality

After pipeline completes:

1. Check `../06.DESeq2_results/ERCC_alignment_stats.csv`
2. View `../06.DESeq2_results/ERCC_percentage_by_sample.pdf`
3. Review `../06.DESeq2_results/size_factor_comparison.pdf`

Expected ERCC %: 1-5% per sample, <20% CV across samples

## ERCC Normalization Rationale

### Why ERCC-based normalization?

Your experimental treatments (BHB, acac, mes, caloric restriction) may cause:
- **Global transcriptional changes** (not just specific genes)
- Changes in **total RNA content per cell**
- Alterations in **cell size** or **growth rate**

Standard DESeq2 normalization assumes:
- Most genes are NOT differentially expressed
- Total mRNA is similar across samples

ERCC normalization:
- Uses **external spike-ins** with known amounts
- Independent of biological changes
- Corrects for **global expression shifts**
- Enables **absolute quantification**

### When ERCC Makes a Difference

Compare in `size_factor_comparison.pdf`:
- **Similar size factors** → Standard normalization is adequate
- **Different size factors** → ERCC is correcting for real global changes

The pipeline uses **ERCC normalization by default** but saves both methods for comparison.

## Key ERCC Metrics to Monitor

| Metric | Good | Warning | Action |
|--------|------|---------|--------|
| **ERCC %** | 1-5% | <1% or >10% | Check spike-in amount |
| **ERCC CV** | <20% | >30% | Check pipetting consistency |
| **ERCC detected** | >80/92 | <70/92 | Check RNA quality |
| **Sample outliers** | None | Present | Investigate sample |

## Files Added/Modified

### New Files:
- `ERCC_SPIKE_IN_GUIDE.md`
- `QUICK_REFERENCE.md`
- `run_full_pipeline.sh`
- `05.5_check_trimming_quality.sh` - QC gating script
- `UPDATE_SUMMARY.md` (this file)

### Modified Files (from ERCC update):
- `00_download_reference.slurm` - ERCC download and concatenation
- `01_fastqc_raw.slurm` - Updated log paths
- `02_multiqc_raw.slurm` - Updated log paths
- `06_build_star_index.slurm` (was 03) - Combined reference + updated paths
- `07_star_align.slurm` (was 04) - Updated log paths
- `08_multiqc_alignment.slurm` (was 05) - Updated log paths
- `09_featureCounts.slurm` (was 06) - Updated log paths
- `10_run_deseq2.slurm` (was 07) - Updated log paths
- `10_deseq2_analysis.R` (was 07) - ERCC normalization logic
- `README.md` - ERCC info + directory structure
- `SETUP_INSTRUCTIONS.md` - New workflow + ERCC QC
- `experimental_design.csv` - No changes (already compatible)

### Modified Files (QC gating update):
- `run_full_pipeline.sh` - Added step 5.5 to pipeline sequence, enhanced `check_step_complete()` to detect QC marker files, integrated QC gating into resume logic
- `05.5_check_trimming_quality.sh` - Creates QC pass/fail marker files based on MultiQC metrics validation

## Backward Compatibility

**Breaking Changes:**
- Scripts must now be run from `BHB_RNAseq/` subdirectory
- Log files now in `../logs/` instead of `logs/`
- Reference files now include ERCC (combined files)

**Non-breaking:**
- Experimental design file format unchanged
- Output directory structure unchanged
- All module versions unchanged
- Can still run steps individually

## Next Steps for User

1. ✅ **Copy updated scripts to HPC**
   ```bash
   rsync -avz --exclude='.git' --exclude='SETUP_INSTRUCTIONS_files' \
       BHB_RNAseq/ $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/BHB_RNAseq/
   ```

2. ✅ **Create logs directory on HPC**
   ```bash
   ssh $USER@login.hpc.virginia.edu
   mkdir -p /scratch/$USER/BHB_complete/logs
   ```

3. ✅ **Verify conda environment exists**
   ```bash
   module load miniforge/24.11.3-py3.12
   conda env list | grep rnaseq_r
   ```

4. ✅ **Run pipeline**
   ```bash
   cd /scratch/$USER/BHB_complete/BHB_RNAseq
   bash run_full_pipeline.sh
   ```

5. ✅ **Monitor and review ERCC QC**
   - Watch job progress: `watch -n 60 'squeue -u $USER'`
   - After completion, review ERCC metrics
   - Download results to local machine

## Documentation Files

| File | Purpose | Use When |
|------|---------|----------|
| **README_pipeline.md** | Complete pipeline overview | Understanding workflow |
| **SETUP_INSTRUCTIONS.md** | Detailed setup and running | First time setup |
| **ERCC_SPIKE_IN_GUIDE.md** | ERCC interpretation guide | Analyzing ERCC results |
| **QUICK_REFERENCE.md** | Command cheat sheet | Daily use |
| **UPDATE_SUMMARY.md** | This file - what changed | Understanding updates |

## Questions or Issues?

- **ERCC not detected**: Check raw data has ERCC reads (should be added during library prep)
- **High ERCC variation**: Review pipetting during spike-in addition
- **Low alignment rate**: Review FastQC reports for quality issues
- **DESeq2 errors**: Verify conda environment installation

Contact: hjs8zu@virginia.edu  
HPC Support: hpc-support@virginia.edu

---

**Summary**: Pipeline now includes full ERCC92 spike-in support with automatic normalization, comprehensive QC, and reorganized directory structure for cleaner workflow management.
