# Transfer and Setup Checklist

Use this checklist to get the pipeline onto UVA HPC and verify everything is ready.

## GitHub Repository

**Repository**: https://github.com/aperium/BHB_RNAseq

## Choose Your Setup Method

### Method 1: Clone from GitHub (Recommended ✓)

**Advantages**: Clean, version-controlled, easy to update

- [ ] SSH into HPC
  ```bash
  ssh $USER@login.hpc.virginia.edu
  ```

- [ ] Navigate to project directory
  ```bash
  cd /scratch/$USER/BHB_complete
  ```

- [ ] Clone the repository
  ```bash
  git clone https://github.com/aperium/BHB_RNAseq.git
  ```

- [ ] Verify clone succeeded
  ```bash
  ls -la BHB_RNAseq/
  ls BHB_RNAseq/*.slurm | wc -l  # Should be 8
  ```

- [ ] Skip to "HPC Setup Checklist" section below

### Method 2: Transfer from Local Machine

**Use this if**: You have local modifications not yet pushed to GitHub

#### Pre-Transfer Checklist (Local Machine)

- [ ] Verify you're in the correct directory
  ```bash
  cd /path/to/your/local/workspace
  ls BHB_RNAseq/
  ```

- [ ] Check that all required files exist locally:
  ```bash
  ls BHB_RNAseq/*.slurm | wc -l          # Should be 8
  ls BHB_RNAseq/*.R | wc -l              # Should be 1
  ls BHB_RNAseq/*.md | wc -l             # Should be 6
  ls BHB_RNAseq/*.sh | wc -l             # Should be 1
  ls BHB_RNAseq/experimental_design.csv  # Should exist
  ```

- [ ] Verify file contents are correct
  ```bash
  # Check for ERCC in reference download script
  grep -q "ERCC" BHB_RNAseq/00_download_reference.slurm && echo "✓ ERCC included"
  
  # Check for updated log paths
  grep -q "../logs/" BHB_RNAseq/04_star_align.slurm && echo "✓ Log paths updated"
  
  # Check for ERCC normalization in R script
  grep -q "ERCC" BHB_RNAseq/07_deseq2_analysis.R && echo "✓ ERCC normalization included"
  ```

#### Transfer to HPC

- [ ] Transfer the entire BHB_RNAseq directory to HPC
  ```bash
  rsync -avz --exclude='.git' --exclude='SETUP_INSTRUCTIONS_files' \
      BHB_RNAseq/ $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/BHB_RNAseq/
  ```

- [ ] Verify transfer completed successfully
  ```bash
  ssh $USER@login.hpc.virginia.edu"ls -la /scratch/$USER/BHB_complete/BHB_RNAseq/"
  ```

### Method 3: Download Release Archive

**Use this if**: No git available, want specific version

- [ ] SSH into HPC
  ```bash
  ssh $USER@login.hpc.virginia.edu
  ```

- [ ] Navigate and download
  ```bash
  cd /scratch/$USER/BHB_complete
  wget https://github.com/aperium/BHB_RNAseq/archive/refs/heads/main.zip
  unzip main.zip
  mv BHB_RNAseq-main BHB_RNAseq
  rm main.zip
  ```

## HPC Setup Checklist

- [ ] SSH into HPC
  ```bash
  ssh $USER@login.hpc.virginia.edu
  ```

- [ ] Navigate to project directory
  ```bash
  cd /scratch/$USER/BHB_complete
  pwd  # Should show: /scratch/$USER/BHB_complete
  ```

- [ ] Verify BHB_RNAseq directory exists
  ```bash
  ls -la BHB_RNAseq/
  ```

- [ ] Verify all scripts transferred correctly
  ```bash
  ls BHB_RNAseq/*.slurm | wc -l  # Should be 8
  ls BHB_RNAseq/*.R | wc -l      # Should be 1
  ls BHB_RNAseq/*.sh | wc -l     # Should be 1
  ```

- [ ] Create logs directory
  ```bash
  mkdir -p logs
  ls -ld logs/  # Should show directory exists
  ```

- [ ] Verify raw data is present
  ```bash
  ls 01.RawData/*/*.fq.gz | wc -l  # Should be 84 (42 samples × 2 files)
  ```

- [ ] Check first few file names to verify naming pattern
  ```bash
  ls 01.RawData/*/*.fq.gz | head -6
  # Look for pattern like: SAMPLE_1.fq.gz and SAMPLE_2.fq.gz
  ```

## Conda Environment Setup

- [ ] Load miniforge module
  ```bash
  module load miniforge/24.11.3-py3.12
  ```

- [ ] Check if rnaseq_r environment already exists
  ```bash
  conda env list | grep rnaseq_r
  ```

- [ ] If NOT exists, create it (takes ~10-15 minutes)
  ```bash
  conda create -y -n rnaseq_r -c conda-forge -c bioconda \
      r-base r-deseq2 r-ggplot2 r-pheatmap r-dplyr \
      r-rcolorbrewer bioconductor-enhancedvolcano
  ```

- [ ] Verify environment was created successfully
  ```bash
  conda env list | grep rnaseq_r  # Should show rnaseq_r
  ```

- [ ] Test environment activation
  ```bash
  conda activate rnaseq_r
  R --version  # Should show R version 4.3+
  conda deactivate
  ```

## Module Availability Check

- [ ] Check required modules are available
  ```bash
  module load star/2.7.11b && echo "✓ STAR"
  module load samtools/1.21 && echo "✓ samtools"
  module load fastqc/0.12.1 && echo "✓ FastQC"
  module load multiqc/1.27.1 && echo "✓ MultiQC"
  module load subread/2.0.10 && echo "✓ Subread (featureCounts)"
  module purge
  ```

## File Permission Check

- [ ] Make scripts executable (optional but recommended)
  ```bash
  cd BHB_RNAseq
  chmod +x *.slurm
  chmod +x *.R
  chmod +x *.sh
  ```

- [ ] Verify master script is executable
  ```bash
  ls -l run_full_pipeline.sh  # Should show x permissions
  ```

## Final Verification

- [ ] Verify directory structure
  ```bash
  cd /scratch/$USER/BHB_complete
  ls -ld BHB_RNAseq/ 01.RawData/ logs/  # All should exist
  ```

- [ ] Check disk space available
  ```bash
  df -h /scratch/$USER/
  # Need at least 100GB free for analysis outputs
  ```

- [ ] Review experimental design file
  ```bash
  cat BHB_RNAseq/experimental_design.csv | head -10
  # Verify sample names match raw data files
  ```

## Ready to Run!

Once all items are checked:

### Option 1: Full Automated Pipeline (Recommended)

- [ ] Run master submission script
  ```bash
  cd /scratch/$USER/BHB_complete/BHB_RNAseq
  bash run_full_pipeline.sh
  ```

- [ ] Verify jobs were submitted
  ```bash
  squeue -u $USER
  # Should show 8 jobs (some pending with dependencies)
  ```

### Option 2: Step-by-Step Execution

- [ ] Submit first step
  ```bash
  cd /scratch/$USER/BHB_complete/BHB_RNAseq
  sbatch 00_download_reference.slurm
  ```

- [ ] Check job started
  ```bash
  squeue -u $USER
  ```

- [ ] Monitor log file
  ```bash
  tail -f ../logs/00_download_ref_*.out
  ```

## Monitoring Setup

- [ ] Setup watch command for continuous monitoring
  ```bash
  watch -n 60 'squeue -u $USER'
  # Press Ctrl+C to exit
  ```

- [ ] Note job IDs for later reference
  ```bash
  squeue -u $USER> ~/my_jobs.txt
  ```

## Expected Timeline

| Stage | Duration | Notes |
|-------|----------|-------|
| Setup & Transfer | 30 min | One-time setup |
| Conda Environment | 15 min | One-time setup |
| Pipeline Execution | 6-8 hours | Automated with dependencies |

## Troubleshooting

If any checkbox fails, see:
- **Module issues**: Check `module avail` for correct version numbers
- **File not found**: Verify paths in `ls` commands
- **Permission denied**: Use `chmod +x` on scripts
- **Conda errors**: Try `conda clean --all` then recreate environment
- **Disk space**: Use `du -sh *` to check directory sizes

## After Pipeline Completes

- [ ] Check all jobs completed successfully
  ```bash
  sacct -u $USER --format=JobID,JobName,State,Elapsed
  # All should show "COMPLETED"
  ```

- [ ] Verify output directories exist
  ```bash
  ls -ld ../00.Reference/ ../03.FastQC_raw/ ../04.Alignment/ \
         ../05.Counts/ ../06.DESeq2_results/
  ```

- [ ] Check ERCC QC files were generated
  ```bash
  ls ../06.DESeq2_results/ERCC_*
  # Should show: ERCC_counts.csv, ERCC_alignment_stats.csv, 
  #              ERCC_percentage_by_sample.pdf
  ```

- [ ] Review ERCC alignment percentages
  ```bash
  cat ../06.DESeq2_results/ERCC_alignment_stats.csv
  # Check ERCC_percentage column: should be 1-5%
  ```

- [ ] Download results to local machine
  ```bash
  # On local machine:
  rsync -avz \
      --exclude='01.RawData' \
      --exclude='04.Alignment/*.bam' \
      $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/ \
      ~/Workspace/BHB_results/
  ```

## Updating from GitHub

If you cloned from GitHub and want to get the latest updates:

- [ ] Pull latest changes
  ```bash
  cd /scratch/$USER/BHB_complete/BHB_RNAseq
  git pull origin main
  ```

- [ ] Check what changed
  ```bash
  git log --oneline -5
  ```

- [ ] If you have local modifications you want to keep
  ```bash
  git stash  # Save your changes
  git pull   # Get updates
  git stash pop  # Reapply your changes
  ```

## Documentation Reference

During setup and execution, refer to:
- [ ] `README.md` - Pipeline overview and quick start
- [ ] `SETUP_INSTRUCTIONS.md` - Detailed setup instructions
- [ ] `QUICK_REFERENCE.md` - Command reference
- [ ] `ERCC_SPIKE_IN_GUIDE.md` - ERCC interpretation (after results)

## Getting Help

If you encounter issues:

1. **Check log files** first: `../logs/*.err`
2. **Review documentation**: See files listed above
3. **UVA HPC support**: hpc-support@virginia.edu
4. **HPC documentation**: https://www.rc.virginia.edu/userinfo/hpc/

---

**Estimated total setup time**: 45 minutes  
**Estimated pipeline runtime**: 6-8 hours (mostly automated)

Good luck with your analysis! 🧬
