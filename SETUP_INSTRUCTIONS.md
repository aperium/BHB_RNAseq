# Setup Instructions for BHB RNA-seq Pipeline on UVA HPC

## GitHub Repository

**Repository**: https://github.com/aperium/BHB_RNAseq

This pipeline is version-controlled on GitHub. You can clone it directly to HPC or transfer from a local copy.

## ⚠️ Important: HPC Account Requirement

**All SLURM job submissions require specifying an allocation account.**

Before running any pipeline steps, find your account name and set the `SLURM_ACCOUNT` variable:

```bash
# Find your account name(s)
allocations

# Set the SLURM_ACCOUNT environment variable (replace with your actual account)
export SLURM_ACCOUNT=your_account_name
```

Common account names at UVA HPC include: `berglandlab`, `bii_dsi_community`, etc.

Then use `--account=${SLURM_ACCOUNT}` with every `sbatch` command:

```bash
sbatch --account=${SLURM_ACCOUNT} script.slurm
```

If you don't have an account, contact your PI or email `hpc-support@virginia.edu`.

### Optional: Make It Permanent

To avoid setting `SLURM_ACCOUNT` every time you log in, add it to your `~/.bashrc`:

```bash
# Add to your ~/.bashrc file (replace with your actual account)
echo 'export SLURM_ACCOUNT=your_account_name' >> ~/.bashrc
source ~/.bashrc

# Now the variable will be set automatically in every new session
```

**Note**: If you work with multiple accounts, you may want to set `SLURM_ACCOUNT` manually each session to avoid confusion.

## Initial Setup (One-Time)

### 1. Get Pipeline Files on HPC

**Option A: Clone from GitHub (Recommended)**

```bash
# SSH into HPC
ssh $USER@login.hpc.virginia.edu

# Navigate to project directory
cd /scratch/$USER/BHB_complete

# Clone the repository
git clone https://github.com/aperium/BHB_RNAseq.git

# OR pull the latest version
git pull

# This creates: /scratch/$USER/BHB_complete/BHB_RNAseq/
```

**Option B: Transfer from Local Machine**

If you have a local copy with modifications:

```bash
# On your local machine (from the directory containing BHB_RNAseq)
cd /path/to/your/local/workspace

# Copy entire directory to HPC
rsync -avz --exclude='.git' --exclude='SETUP_INSTRUCTIONS_files' \
    BHB_RNAseq/ $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/BHB_RNAseq/
```

**Option C: Download Latest Release**

```bash
# SSH into HPC
ssh $USER@login.hpc.virginia.edu
cd /scratch/$USER/BHB_complete

# Download and extract latest release
wget https://github.com/aperium/BHB_RNAseq/archive/refs/heads/main.zip
unzip main.zip
mv BHB_RNAseq-main BHB_RNAseq
rm main.zip
```

This creates a clean directory structure:
```
/scratch/$USER/BHB_complete/
├── BHB_RNAseq/          # Pipeline scripts and documentation (copied from local)
├── 01.RawData/          # Raw FASTQ files (already on HPC)
├── logs/                # SLURM job logs (will be created)
├── 00.Reference/        # Reference files (will be created)
├── 02.TrimmedData/      # Trimmed FASTQ files (will be created)
├── 03.FastQC_raw/       # QC outputs (will be created)
├── 04.Alignment/        # Alignment outputs (will be created)
├── 05.Counts/           # Count matrices (will be created)
└── 06.DESeq2_results/   # Final results (will be created)
```

### 2. Create Directory Structure on HPC

```bash
# SSH into HPC
ssh $USER@login.hpc.virginia.edu

# Navigate to project directory
cd /scratch/$USER/BHB_complete

# Create logs directory
mkdir -p logs

# Verify the script directory was copied
ls BHB_RNAseq/

# Verify raw data location
ls 01.RawData/
```

### 3. Set Up Conda Environment for R/DESeq2

This is needed for the differential expression analysis step:

```bash
# Navigate to the script directory
cd /scratch/$USER/BHB_complete/BHB_RNAseq/

# Load miniforge module
# module avail miniforge #check for avalible versions 
module load miniforge/24.11.3-py3.12

# Create conda environment with R and bioinformatics packages
conda create -y -n rnaseq_r -c conda-forge -c bioconda \
    r-base=4.3 \
    bioconductor-deseq2 \
    r-ggplot2 \
    r-pheatmap \
    r-dplyr \
    r-rcolorbrewer \
    bioconductor-enhancedvolcano

# This may take 10-15 minutes
```

### 4. Make Scripts Executable (Optional)

```bash
chmod +x *.slurm
chmod +x *.R
chmod +x *.sh
```

## Verify Setup

### Check Raw Data Structure

```bash
# Check how many samples you have
ls ../01.RawData/*/*.fq.gz | wc -l
# Should be 84 files (42 samples × 2 read files)

# Check a few file names to verify naming convention
ls ../01.RawData/*/*.fq.gz | head -10
```

**Important**: If your files have different naming (e.g., `_R1_001.fastq.gz` instead of `_1.fq.gz`), you'll need to adjust the file finding pattern in `04_star_align.slurm`.

### Verify Module Availability

```bash
module load star
module load samtools
module load fastqc
module load multiqc
module load trimmomatic

# If all load without error, you're good!
module purge
```

## Running the Pipeline

### Setting Up Your Account Variable

**IMPORTANT**: All SLURM job submissions require the `SLURM_ACCOUNT` environment variable.

```bash
# Check your available allocations
allocations

# This will show something like:
# Account: your_account_name
# Available SUs: 50000

# Set the variable (replace with your actual account name)
export SLURM_ACCOUNT=berglandlab
```

Use `--account=${SLURM_ACCOUNT}` in all `sbatch` commands:

```bash
sbatch --account=${SLURM_ACCOUNT} script.slurm
```

### Option 1: Automated Full Pipeline (Recommended)

Submit all jobs at once with automatic dependencies:

```bash
# SSH into HPC and navigate to script directory
ssh $USER@login.hpc.virginia.edu
cd /scratch/$USER/BHB_complete/BHB_RNAseq

# Set your account variable (if not already set)
export SLURM_ACCOUNT=your_account_name

# Run master submission script (passes account to all sbatch commands)
bash run_full_pipeline.sh ${SLURM_ACCOUNT}

# Or let it default to $USER (if your account matches your username)
bash run_full_pipeline.sh
```

This will submit all 11 steps with job dependencies. Each step will automatically start when its prerequisites complete. Total runtime: ~8-10 hours.

Monitor progress:
```bash
watch -n 60 'squeue -u $USER'
```

### Option 2: Step-by-Step Execution (For Testing/Debugging)

```bash
# SSH into HPC and navigate to script directory
ssh $USER@login.hpc.virginia.edu
cd /scratch/$USER/BHB_complete/BHB_RNAseq

# Find your account name first!
allocations

# Set your account variable first!
export SLURM_ACCOUNT=your_account_name

# All scripts should be run from the BHB_RNAseq directory
# Logs will be written to ../logs/ (one level up)

# Step 0: Download reference
sbatch --account=${SLURM_ACCOUNT} 00_download_reference.slurm
# Wait for completion, check: squeue -u $USER

# Step 1: QC raw reads
sbatch --account=${SLURM_ACCOUNT} 01_fastqc_raw.slurm

# Step 2: Aggregate QC
sbatch --account=${SLURM_ACCOUNT} 02_multiqc_raw.slurm
# Review: ../03.FastQC_raw/multiqc_raw_report.html

# Step 3: Quality trimming
sbatch --account=${SLURM_ACCOUNT} 03_trimmomatic.slurm

# Step 4: QC trimmed reads
sbatch --account=${SLURM_ACCOUNT} 04_fastqc_trimmed.slurm

# Step 5: Aggregate QC for trimmed reads
sbatch --account=${SLURM_ACCOUNT} 05_multiqc_trimmed.slurm
# Review: ../02.TrimmedData/multiqc_trimmed_report.html

# Step 6: Build STAR index
sbatch --account=${SLURM_ACCOUNT} 06_build_star_index.slurm

# Step 7: Align reads
sbatch --account=${SLURM_ACCOUNT} 07_star_align.slurm

# Monitor array job progress:
squeue -u $USER
watch -n 60 'squeue -u $USER'  # Updates every 60 seconds

# Step 8: Aggregate alignment QC
sbatch --account=${SLURM_ACCOUNT} 08_multiqc_alignment.slurm

# Step 9: Create count matrix
sbatch --account=${SLURM_ACCOUNT} 09_featureCounts.slurm

# Step 10: DESeq2 analysis
sbatch --account=${SLURM_ACCOUNT} 10_run_deseq2.slurm
```



## Monitoring and Debugging

### Check Job Status

```bash
# View all your jobs
squeue -u $USER

# Check specific array job details
squeue -j JOBID --array

# View completed jobs
sacct -u $USER--starttime=2025-11-05
```

### View Logs

```bash
# Navigate to logs directory (one level up from scripts)
cd /scratch/$USER/BHB_complete/logs

# Real-time monitoring
tail -f 04_star_align_JOBID_TASKID.out

# Check for errors
grep -i error *.err
grep -i warning *.err

# Check alignment rates
grep "Uniquely mapped reads" 04_star_align_*.out

# Or monitor from script directory
cd /scratch/$USER/BHB_complete/BHB_RNAseq
tail -f ../logs/04_star_align_JOBID_TASKID.out
```

### Common Issues

**Issue**: Job submission fails with "Account not specified" or "Invalid account"

```bash
# Check your available accounts
allocations

# If no accounts are shown, request access:
# Contact your PI or email hpc-support@virginia.edu
```

**Issue**: Array job task fails to find FASTQ files

```bash
# Check actual file structure
ls -R 01.RawData/ | head -50

# Modify 04_star_align.slurm line 38-39 to match your file pattern
# Example if files are named differently:
R1=$(find ${RAW_DIR} -name "${SAMPLE}*_R1*.fq.gz" | head -1)
```

**Issue**: STAR index build fails

```bash
# Check reference files downloaded correctly
ls -lh 00.Reference/
md5sum 00.Reference/*.fa 00.Reference/*.gtf
```

**Issue**: DESeq2 fails with package errors

```bash
# Reinstall conda environment
conda env remove -n rnaseq_r
conda create -y -n rnaseq_r -c conda-forge -c bioconda \
    r-base=4.3 r-deseq2 r-ggplot2 r-pheatmap r-dplyr \
    r-rcolorbrewer bioconductor-enhancedvolcano
```

## Transferring Results Back to Local Machine

```bash
# On your local machine
cd ~/Downloads

# Download MultiQC reports
scp $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/03.FastQC_raw/multiqc_raw_report.html ./BHB_results/

# Download DESeq2 results (includes ERCC QC)
scp -r $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/06.DESeq2_results ./BHB_results/

# Download all results (excluding raw data and BAMs)
rsync -avz \
    --exclude='01.RawData' \
    --exclude='04.Alignment/*.bam' \
    $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/\
    ./BHB_results/
```

Key files to review:
- `03.FastQC_raw/multiqc_raw_report.html` - Read quality
- `04.Alignment/multiqc_alignment_report.html` - Alignment statistics  
- `06.DESeq2_results/ERCC_percentage_by_sample.pdf` - ERCC QC
- `06.DESeq2_results/ERCC_alignment_stats.csv` - ERCC metrics
- `06.DESeq2_results/PCA_plot.pdf` - Sample clustering
- `06.DESeq2_results/DE_summary.csv` - Overview of all comparisons

## ERCC Spike-in Quality Control

This pipeline includes ERCC92 spike-in controls. After DESeq2 completes, review:

### Key ERCC Metrics

1. **ERCC Percentage**: Check `06.DESeq2_results/ERCC_percentage_by_sample.pdf`
   - Expected: 1-5% of total reads
   - Should be consistent across samples
   - High variation indicates pipetting issues

2. **ERCC Alignment Stats**: Review `06.DESeq2_results/ERCC_alignment_stats.csv`
   - Look for outlier samples
   - Check if ERCC % is uniform

3. **Normalization Comparison**: Examine `06.DESeq2_results/size_factor_comparison.pdf`
   - Compares ERCC-based vs standard DESeq2 normalization
   - Large differences suggest global expression changes

### ERCC Quality Criteria

✅ **Good quality:**
- ERCC % is 1-5% across all samples
- Coefficient of variation (CV) < 20%
- 80-92 ERCC transcripts detected

⚠️ **Investigate if:**
- ERCC % varies widely between samples (>2-fold difference)
- ERCC % < 1% or > 10%
- Size factors differ dramatically between methods

📖 **For detailed ERCC interpretation, see `ERCC_SPIKE_IN_GUIDE.md`**

## Updating the Pipeline

If you cloned from GitHub and updates are available:

```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq

# Check for updates
git fetch
git status

# Pull latest changes
git pull origin main

# View recent changes
git log --oneline -10
```

**If you have local modifications:**
```bash
# Save your changes temporarily
git stash

# Get updates
git pull origin main

# Reapply your changes
git stash pop

# Or commit your changes first
git add .
git commit -m "My local modifications"
git pull origin main
```

## Customizing for Your Needs

### Adding Trimming Step

If QC shows adapter contamination, add between steps 2 and 3:

```bash
# Create trimmomatic script (trimmomatic/0.40 is available)
# This would be a new 02b_trimmomatic.slurm script
```

### Changing Comparisons in DESeq2

Edit `07_deseq2_analysis.R` to add custom contrasts:

```R
# Example: Compare BHB vs control in stationary phase
res_stat_B_vs_C <- extract_results(dds,
    contrast = c("treatment", "B", "C"),
    comparison_name = "stat_BHB_vs_control")
```

### Adjusting Resource Allocation

If jobs fail due to memory/time, edit the SLURM directives:

```bash
#SBATCH --mem=64G      # Increase memory
#SBATCH --time=8:00:00 # Increase time limit
```

## Quick Reference Card

```bash
# IMPORTANT: Set your account variable first!
allocations
export SLURM_ACCOUNT=your_account_name

# Submit a job (use --account=${SLURM_ACCOUNT})
sbatch --account=${SLURM_ACCOUNT} script.slurm

# Check queue
squeue -u $USER

# Cancel job
scancel JOBID

# Cancel all your jobs
scancel -u $USER

# View job details
scontrol show job JOBID

# Check allocation usage
allocations

# Disk usage
du -sh /scratch/$USER/BHB_complete/
```

## Support

- **UVA HPC Documentation**: https://www.rc.virginia.edu/userinfo/hpc/
- **HPC Support**: hpc-support@virginia.edu
- **SLURM Documentation**: https://slurm.schedmd.com/
