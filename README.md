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

2. **Complete setup**: Follow instructions in `SETUP_INSTRUCTIONS.md`

3. **Run the pipeline**: See Quick Start section below

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

### Option 1: Run Entire Pipeline Automatically
```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
bash run_full_pipeline.sh
```
This submits all 8 steps with job dependencies. Jobs will run automatically as dependencies complete (~6-8 hours total).

### Option 2: Run Steps Individually

## Pipeline Steps

### Step 0: Download Reference Genome
```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
sbatch 00_download_reference.slurm
```
Downloads *S. cerevisiae* R64-1-1 genome (Ensembl release 113), GTF annotation, and ERCC92 spike-in references. Combines them into unified reference files for alignment.

### Step 1: Quality Control - Raw Reads
```bash
sbatch 01_fastqc_raw.slurm
```
Runs FastQC on all raw FASTQ files to assess read quality.

### Step 2: Aggregate QC Reports
```bash
sbatch 02_multiqc_raw.slurm
```
Creates a MultiQC report summarizing FastQC results across all samples.

**Decision Point**: Review `../03.FastQC_raw/multiqc_raw_report.html`. If quality is poor, add trimming step.

### Step 3: Build STAR Index
```bash
sbatch 03_build_star_index.slurm
```
Builds STAR genome index with combined yeast + ERCC reference, optimized for yeast genome size.

### Step 4: Align Reads with STAR
```bash
sbatch 04_star_align.slurm
```
Array job (1-42) that aligns all samples in parallel. Each sample gets:
- Sorted BAM file
- BAM index
- Gene counts (ReadsPerGene.out.tab)
- Alignment statistics

### Step 5: Aggregate Alignment QC
```bash
sbatch 05_multiqc_alignment.slurm
```
Creates MultiQC report for alignment statistics (alignment rate, uniqueness, etc.).

### Step 6: Create Count Matrix
```bash
sbatch 06_featureCounts.slurm
```
Extracts gene counts from STAR output and creates a combined count matrix.

Output: `../05.Counts/counts_matrix_unstranded.txt` (genes × samples)

### Step 7: Differential Expression Analysis
```bash
# First, set up conda environment (one-time setup, from any directory)
module load miniforge/24.11.3-py3.12
conda create -y -n rnaseq_r -c conda-forge -c bioconda \
    r-base r-deseq2 r-ggplot2 r-pheatmap r-dplyr \
    r-rcolorbrewer bioconductor-enhancedvolcano

# Then run DESeq2 (from BHB_RNAseq directory)
cd /scratch/$USER/BHB_complete/BHB_RNAseq
sbatch 07_run_deseq2.slurm
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
tail -f ../logs/04_star_align_JOBID_ARRAYID.out

# Or from logs directory
cd /scratch/$USER/BHB_complete/logs
tail -f 04_star_align_JOBID_ARRAYID.out

# Cancel a job
scancel JOBID
```

## Expected Runtime

- Step 0 (Download): ~30 min
- Step 1 (FastQC): ~2-3 hours
- Step 2 (MultiQC): ~5 min
- Step 3 (STAR index): ~15 min
- Step 4 (Alignment): ~2-3 hours (parallelized)
- Step 5 (MultiQC): ~5 min
- Step 6 (Counts): ~10 min
- Step 7 (DESeq2): ~1 hour

**Total**: ~6-8 hours (mostly parallelized)

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

### If FASTQ files aren't found in Step 4:
The script searches for files matching `${SAMPLE}*_[12].fq.gz`. If Novogene uses different naming:
1. Check actual file names: `ls /scratch/$USER/BHB_complete/01.RawData/`
2. Adjust the `find` command in `04_star_align.slurm`

### If alignment rates are low (<70%):
- Check FastQC reports for adapter contamination
- May need to add trimming step with Trimmomatic
- Verify correct reference genome

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
