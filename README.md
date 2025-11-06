# BHB RNA-seq Analysis Pipeline

This pipeline analyzes paired-end RNA-seq data from *Saccharomyces cerevisiae* with multiple treatment conditions across log and stationary growth phases.

## GitHub Repository

**Repository**: https://github.com/aperium/BHB_RNAseq

This pipeline is version-controlled on GitHub for easy deployment to UVA HPC.

## Getting Started

**New to this project?** Follow these steps:

1. **Clone this repository on UVA HPC**:
   ```bash
   ssh $USER@login.hpc.virginia.edu
   cd /scratch/$USER/BHB_complete
   git clone https://github.com/aperium/BHB_RNAseq.git
   ```

2. **Find your HPC allocation account** (required for all job submissions):
   ```bash
   allocations
   ```

3. **Set the SLURM_ACCOUNT environment variable**:
   ```bash
   export SLURM_ACCOUNT=your_account_name
   ```

4. **Complete setup**: Follow instructions in `SETUP_INSTRUCTIONS.md`

5. **Run the pipeline**: See Quick Start section below

For detailed transfer instructions from local machine or GitHub, see `TRANSFER_CHECKLIST.md`.

## Experimental Design

- **Organism**: *Saccharomyces cerevisiae* (yeast)
- **Sequencing**: Paired-end Illumina reads
- **Samples**: 42 total
- **Spike-ins**: ERCC92 Mix 1 (for normalization and QC)
- **Factors**:
  - **Phase**: log (logarithmic growth) vs stat (stationary phase)
  - **Treatments**: N (nonrestricted), B (BHB), L (acac), M (mes), C (control), BM, LM
  - **Replicates**: 3 biological replicates per condition (some exceptions)

> **Note**: This pipeline includes ERCC92 spike-in controls for improved normalization. See `ERCC_SPIKE_IN_GUIDE.md` for detailed information.

## Directory Structure

```
/scratch/$USER/BHB_complete/
├── BHB_RNAseq/               # Pipeline scripts and documentation
│   ├── *.slurm               # SLURM job submission scripts
│   ├── *.R                   # R analysis scripts
│   ├── *.md                  # Documentation
│   └── experimental_design.csv
├── 00.Reference/             # Reference genome and annotations
│   ├── STAR_index/          # STAR genome index (yeast + ERCC)
│   ├── Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa
│   ├── Saccharomyces_cerevisiae.R64-1-1.113.gtf
│   ├── ERCC92.fa            # ERCC spike-in sequences
│   ├── ERCC92.gtf           # ERCC spike-in annotation
│   ├── combined_genome.fa   # Yeast + ERCC combined
│   └── combined_annotation.gtf
├── 01.RawData/              # Raw FASTQ files from Novogene
├── 02.TrimmedData/          # Quality-trimmed FASTQ files (Trimmomatic)
│   └── fastqc/              # FastQC reports on trimmed reads
├── 03.FastQC_raw/           # FastQC reports on raw reads
├── 04.Alignment/            # STAR alignment outputs (BAM files)
├── 05.Counts/               # Gene count matrices (yeast + ERCC)
├── 06.DESeq2_results/       # Differential expression results
│   ├── ERCC_counts.csv      # ERCC spike-in counts
│   ├── ERCC_alignment_stats.csv
│   └── size_factor_comparison.csv
└── logs/                    # SLURM job logs
```

**Important**: All scripts must be run from the `BHB_RNAseq` directory:
```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
sbatch 00_download_reference.slurm
```

## Quick Start

**Important**: All `sbatch` commands require specifying your HPC allocation account. First, set the `SLURM_ACCOUNT` variable:

```bash
# Find your account name(s)
allocations

# Set the SLURM_ACCOUNT variable (replace with your actual account)
export SLURM_ACCOUNT=your_account_name
```

Replace `your_account_name` with your actual HPC allocation

**Example workflow:**
```bash
# First time: Find your account
allocations

# Set the variable for your session
export SLURM_ACCOUNT=your_account_name

# Now submit jobs using that account
sbatch --account=${SLURM_ACCOUNT} 00_download_reference.slurm
sbatch --account=${SLURM_ACCOUNT} 01_fastqc_raw.slurm
# ... and so on
```

### Option 1: Run Entire Pipeline Automatically
```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq

# Set your account (if not already set)
export SLURM_ACCOUNT=your_account_name

# Run with account specified
bash run_full_pipeline.sh ${SLURM_ACCOUNT}

# Or let it default to $USER (if your account matches your username)
bash run_full_pipeline.sh
```
This submits all 11 steps with job dependencies. Jobs will run automatically as dependencies complete (~8-10 hours total).

**Resume from checkpoint:** If the pipeline was interrupted or failed partway through, resume from the last successfully completed step:

```bash
bash run_full_pipeline.sh --resume ${SLURM_ACCOUNT}
```

The `--resume` flag:
- Checks for output files from each step
- Skips steps that completed successfully
- Only submits jobs for incomplete steps
- Maintains proper dependencies between new and completed steps

This saves time and compute resources by not re-running expensive steps (e.g., Trimmomatic, STAR alignment).

### Option 2: Run Steps Individually

## Pipeline Steps

### Step 0: Download Reference Genome
```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
sbatch --account=${SLURM_ACCOUNT} 00_download_reference.slurm
```
Downloads *S. cerevisiae* R64-1-1 genome (Ensembl release 113), GTF annotation, and ERCC92 spike-in references. Combines them into unified reference files for alignment.

### Step 1: Quality Control - Raw Reads
```bash
sbatch --account=${SLURM_ACCOUNT} 01_fastqc_raw.slurm
```
Runs FastQC on all raw FASTQ files to assess read quality.

### Step 2: Aggregate QC Reports - Raw
```bash
sbatch --account=${SLURM_ACCOUNT} 02_multiqc_raw.slurm
```
Creates a MultiQC report summarizing FastQC results for raw reads across all samples.

### Step 3: Quality Trimming with Trimmomatic
```bash
sbatch --account=${SLURM_ACCOUNT} 03_trimmomatic.slurm
```
Array job (1-42) that performs quality trimming and adapter removal on all samples in parallel:
- **Adapter removal**: NextSeq/TruSeq adapters for NovaSeq platform
- **Quality filtering**: SLIDINGWINDOW:4:20 (average quality ≥20 in 4-base window)
- **Length filtering**: MINLEN:36 (discard reads <36bp after trimming)
- **Output**: Paired-end trimmed reads only (unpaired reads discarded)

Output: `../02.TrimmedData/*_R1_paired.fastq.gz` and `*_R2_paired.fastq.gz`

### Step 4: Quality Control - Trimmed Reads
```bash
sbatch --account=${SLURM_ACCOUNT} 04_fastqc_trimmed.slurm
```
Runs FastQC on all trimmed FASTQ files to verify trimming improved quality.

### Step 5: Aggregate QC Reports - Trimmed
```bash
sbatch --account=${SLURM_ACCOUNT} 05_multiqc_trimmed.slurm
```
Creates MultiQC report for trimmed reads. Compare with raw reads report to confirm quality improvement.

**Quality Check**: Review both `../03.FastQC_raw/multiqc_raw_report.html` and `../02.TrimmedData/fastqc/multiqc_trimmed_report.html` to verify trimming effectiveness before proceeding to alignment.

### Step 6: Build STAR Index
```bash
sbatch --account=${SLURM_ACCOUNT} 06_build_star_index.slurm
```
Builds STAR genome index with combined yeast + ERCC reference, optimized for yeast genome size. Can run in parallel with QC/trimming steps.

### Step 7: Align Reads with STAR
```bash
sbatch --account=${SLURM_ACCOUNT} 07_star_align.slurm
```
Array job (1-42) that aligns all **trimmed** samples in parallel. Each sample gets:
- Sorted BAM file
- BAM index
- Gene counts (ReadsPerGene.out.tab)
- Alignment statistics

### Step 8: Aggregate Alignment QC
```bash
sbatch --account=${SLURM_ACCOUNT} 08_multiqc_alignment.slurm
```
Creates MultiQC report for alignment statistics (alignment rate, uniqueness, etc.).

### Step 9: Create Count Matrix
```bash
sbatch --account=${SLURM_ACCOUNT} 09_featureCounts.slurm
```
Extracts gene counts from STAR output and creates a combined count matrix.

Output: `../05.Counts/counts_matrix_unstranded.txt` (genes × samples)

### Step 10: Differential Expression Analysis
```bash
# First, set up conda environment (one-time setup, from any directory)
module load miniforge/24.11.3-py3.12
conda create -y -n rnaseq_r -c conda-forge -c bioconda \
    r-base r-deseq2 r-ggplot2 r-pheatmap r-dplyr \
    r-rcolorbrewer bioconductor-enhancedvolcano

# Then run DESeq2 (from BHB_RNAseq directory)
cd /scratch/$USER/BHB_complete/BHB_RNAseq
sbatch --account=${SLURM_ACCOUNT} 10_run_deseq2.slurm
```

Performs differential expression analysis using DESeq2 with ERCC normalization:
- **ERCC-based normalization** (corrects for global expression changes)
- Separation of ERCC and gene counts
- ERCC quality control metrics
- Statistical testing with multiple comparisons:
  - Treatment effects within each phase
  - Phase effects within treatments
- QC visualizations (PCA, sample distances, ERCC plots)
- Volcano plots and MA plots
- Comparison of ERCC vs standard normalization

See `ERCC_SPIKE_IN_GUIDE.md` for detailed explanation of ERCC normalization.

## Key Comparisons

The DESeq2 script performs these main comparisons:

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
- Stationary vs log in nonrestricted
- Stationary vs log in BHB

## Output Files

### Counts
- `05.Counts/counts_matrix_unstranded.txt` - Raw count matrix (yeast genes + ERCC)

### DESeq2 Results
- `06.DESeq2_results/dds.rds` - DESeq2 object (for further analysis in R)
- `06.DESeq2_results/normalized_counts.csv` - ERCC-normalized counts (yeast genes only)
- `06.DESeq2_results/DE_summary.csv` - Summary of all comparisons
- `06.DESeq2_results/DESeq2_*.csv` - Individual comparison results

### ERCC Quality Control
- `06.DESeq2_results/ERCC_counts.csv` - Raw ERCC spike-in counts
- `06.DESeq2_results/ERCC_alignment_stats.csv` - ERCC alignment statistics per sample
- `06.DESeq2_results/ERCC_percentage_by_sample.pdf` - ERCC % visualization
- `06.DESeq2_results/size_factor_comparison.csv` - ERCC vs standard normalization
- `06.DESeq2_results/size_factor_comparison.pdf` - Normalization method comparison

### Visualizations
- `06.DESeq2_results/PCA_plot.pdf` - Principal component analysis
- `06.DESeq2_results/sample_distance_heatmap.pdf` - Sample clustering
- `06.DESeq2_results/MA_plot_*.pdf` - MA plots for each comparison
- `06.DESeq2_results/volcano_*.pdf` - Volcano plots for each comparison

## Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# Check specific job
squeue -j JOBID

# View recent log (from BHB_RNAseq directory)
tail -f ../logs/03_trimmomatic_JOBID.out

# Or from logs directory
cd /scratch/$USER/BHB_complete/logs
tail -f 03_trimmomatic_JOBID.out

# Cancel a job
scancel JOBID

# Check your account's remaining allocation
allocations
```

## Expected Runtime

- Step 0 (Download): ~30 min
- Step 1 (FastQC raw): ~2-3 hours
- Step 2 (MultiQC raw): ~5 min
- Step 3 (Trimmomatic): ~1-2 hours (parallelized)
- Step 4 (FastQC trimmed): ~2-3 hours
- Step 5 (MultiQC trimmed): ~5 min
- Step 6 (STAR index): ~15 min (runs parallel with QC steps)
- Step 7 (Alignment): ~2-3 hours (parallelized)
- Step 8 (MultiQC alignment): ~5 min
- Step 9 (Counts): ~10 min
- Step 10 (DESeq2): ~1 hour

**Total**: ~8-10 hours (mostly parallelized)

## Updating the Pipeline

If you cloned from GitHub, you can easily get updates:

```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
git pull origin main
```

To see what changed:
```bash
git log --oneline -10
```

**Note**: If you've made local modifications, stash them before pulling:
```bash
git stash        # Save your changes
git pull         # Get updates
git stash pop    # Reapply your changes
```

## Troubleshooting

### If FASTQ files aren't found in Step 3 (Trimmomatic):
The script searches for raw files matching `${SAMPLE}*_[12].fq.gz`. If Novogene uses different naming:
1. Check actual file names: `ls /scratch/$USER/BHB_complete/01.RawData/`
2. Adjust the `find` command in `03_trimmomatic.slurm`

### If trimmed files aren't found in Step 7 (Alignment):
The script searches for trimmed files `${SAMPLE}*_R[12]_paired.fastq.gz`:
1. Check trimmomatic output: `ls /scratch/$USER/BHB_complete/02.TrimmedData/`
2. Verify trimmomatic completed successfully: check logs for errors

### If alignment rates are low (<70%):
- Check FastQC reports for remaining adapter contamination
- Review trimmomatic logs to ensure trimming completed successfully
- Verify correct reference genome
- Check MultiQC reports comparing raw vs trimmed data quality

### If R packages are missing:
```bash
module load miniforge/24.11.3-py3.12
source activate rnaseq_r
R
# In R:
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install(c("DESeq2", "EnhancedVolcano"))
```

## Next Steps After Pipeline

1. **Review ERCC QC** - Check `ERCC_alignment_stats.csv` and `ERCC_percentage_by_sample.pdf`
   - Verify ERCC % is consistent across samples (1-5% typical)
   - Check for outlier samples
2. **Review QC reports** (MultiQC HTML files)
   - FastQC: read quality, adapter content
   - Alignment: mapping rates, uniqueness
3. **Examine normalization** - Compare ERCC-based vs standard in `size_factor_comparison.pdf`
4. **Examine PCA plot** - look for batch effects or outliers
5. **Review DE summary** - identify most responsive conditions
6. **Gene Ontology enrichment** - analyze functional categories of DE genes
7. **Pathway analysis** - KEGG pathways affected by treatments
8. **Visualization** - heatmaps of top DE genes across conditions

**Important**: Review `ERCC_SPIKE_IN_GUIDE.md` for interpreting ERCC results and quality control metrics.

## Contact

For questions about the pipeline, please open an issue on the GitHub repository.
