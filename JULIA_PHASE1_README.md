# Julia Integration - Phase 1: QC and Validation

This document describes the **Phase 1** Julia integration into the BHB RNA-seq pipeline. This is a **low-risk, additive-only** enhancement that provides additional quality control and validation without replacing any existing pipeline functionality.

## Overview

**Phase 1 Goal:** Add Julia-based QC/validation scripts to gain experience with Julia on the HPC cluster while providing useful diagnostic information about your count data.

**Status:** ✅ Implemented (non-disruptive addition)

## What Phase 1 Adds

### New Files

1. **`scripts/validate_counts_qc.jl`** - Main QC validation script
   - Validates all individual STAR count files
   - Analyzes the combined count matrix
   - Cross-validates individual files against the matrix
   - Generates detailed statistics and reports
   - Identifies potential issues (missing files, low counts, outliers)

2. **`09.5_validate_counts_qc.slurm`** - SLURM job script
   - Runs the Julia QC script on compute nodes
   - Handles Julia module loading and package checking
   - Minimal resource requirements (1 CPU, 8GB RAM, 15 min)

3. **`scripts/setup_julia_env.sh`** - Setup script
   - Installs required Julia packages on login node
   - Run once before first use
   - Ensures reproducible package environment

## Installation & Setup

### Step 1: Setup Julia Environment (One-time)

On the HPC **login node**, run:

```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
bash scripts/setup_julia_env.sh
```

This will:
- Load Julia 1.11.6
- Install required packages (DataFrames, CSV, Statistics)
- Verify installation

**Expected output:**
```
Julia Environment Setup
Julia version: julia version 1.11.6
Installing packages...
  → DataFrames
  → CSV
  → Statistics
✓ All packages successfully installed and tested
```

### Step 2: Run the QC Validation (After Step 09)

After your `09_featureCounts.slurm` job completes successfully, run:

```bash
sbatch 09.5_validate_counts_qc.slurm
```

**Or manually:**
```bash
module load julia/1.11.6
julia scripts/validate_counts_qc.jl /scratch/$USER/BHB_complete
```

## What the QC Script Does

### 1. Directory Validation
- Checks that alignment and count directories exist
- Verifies directory structure

### 2. Individual STAR File Validation
For each of 42 samples:
- ✓ File exists
- ✓ File size and line count
- ✓ Number of genes detected
- ✓ Total read counts
- ✓ ERCC spike-in detection
- ⚠ Flags low count samples or missing files

### 3. Combined Matrix Validation
- ✓ Dimensions (genes × samples)
- ✓ All 42 samples present
- ✓ Gene IDs match expected format
- ✓ ERCC vs. yeast gene counts
- ✓ Per-sample statistics (total counts, nonzero genes, ERCC %)

### 4. Cross-Validation
- Compares individual STAR files against the combined matrix
- Ensures counts match exactly
- Identifies any discrepancies

### 5. Statistical Summary
- Overall count statistics (mean, median, range)
- ERCC percentage across samples
- Outlier detection using median absolute deviation
- Identifies samples with unusually low counts

## Output Files

After running, you'll find:

```
05.Counts/
├── julia_qc_report.txt              # Full QC report (human-readable)
├── julia_qc_star_validation.csv     # Detailed STAR file validation
└── julia_qc_matrix_stats.csv        # Per-sample count statistics
```

### Example Output Sections

**STAR File Validation:**
```
  ✓ log_LM_3     :   15,234,567 counts (  32450 genes,   92 ERCC) [OK]
  ✓ log_C_1      :   18,456,123 counts (  31876 genes,   92 ERCC) [OK]
  ⚠ stat_N_1     :      892,445 counts (  15234 genes,   89 ERCC) [LOW_COUNTS]
```

**Matrix Statistics:**
```
Dimensions:
  - Genes: 33179
  - Samples: 42
  - Expected samples: 42
  
Gene composition:
  - Yeast genes: 33087
  - ERCC spike-ins: 92

Overall statistics:
  - Mean counts per sample: 12,456,789
  - Median counts per sample: 11,987,654
  - Min/Max counts: 892,445 / 22,345,678
  - Mean ERCC percentage: 3.42%
```

## Integration with Existing Pipeline

### Option 1: Run Manually (Recommended for Phase 1)

Keep your existing pipeline unchanged and run Julia QC as an additional diagnostic step:

```bash
# Run your normal pipeline
sbatch 09_featureCounts.slurm

# After it completes, run Julia QC for validation
sbatch 09.5_validate_counts_qc.slurm
```

### Option 2: Add to Pipeline (Optional)

If you want to integrate it into `run_full_pipeline.sh`, add after Step 9:

```bash
# Step 9.5: Julia QC Validation (optional)
if [[ "$RESUME" == true ]] && [[ -f "../05.Counts/julia_qc_report.txt" ]]; then
    echo "Step 9.5 (Julia QC): ✓ ALREADY COMPLETE (skipping)"
    JOB9_5="completed"
else
    DEP_STRING=""
    [[ "$JOB9" != "completed" ]] && DEP_STRING="--dependency=afterok:$JOB9"
    JOB9_5=$(sbatch --parsable --account=${SLURM_ACCOUNT} ${DEP_STRING} 09.5_validate_counts_qc.slurm)
    if [[ "$JOB9" == "completed" ]]; then
        echo "Step 9.5 (Julia QC): Job ID $JOB9_5"
    else
        echo "Step 9.5 (Julia QC): Job ID $JOB9_5 (waits for $JOB9)"
    fi
fi
```

## Benefits of Phase 1

✅ **Low Risk:** Doesn't touch any existing code or workflows  
✅ **Additive:** Provides extra validation without changing pipeline  
✅ **Fast:** Completes in ~1-2 minutes for 42 samples  
✅ **Educational:** Demonstrates Julia on HPC with real data  
✅ **Diagnostic:** Catches issues that might be missed otherwise  
✅ **Foundation:** Proves Julia setup works before more ambitious rewrites  

## Performance

**Typical runtime:** 1-2 minutes for 42 samples  
**Memory usage:** ~2-4 GB  
**CPU:** Single-threaded (can be parallelized in Phase 2)

Compare to bash/awk approach:
- **Similar speed** for this simple validation task
- **Much cleaner code** (350 lines vs. likely 500+ bash)
- **Better error handling** and diagnostics
- **Easier to extend** with more sophisticated analyses

## Troubleshooting

### Julia packages not found
```bash
# On login node
module load julia/1.11.6
julia -e 'using Pkg; Pkg.add(["DataFrames", "CSV", "Statistics"])'
```

### Module not available
```bash
module spider julia  # Check available versions
```

If Julia isn't available on your cluster, contact HPC support or skip Phase 1.

### Permission errors
Make sure you're running from the correct directory:
```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
```

## Next Steps (Future Phases)

Phase 1 is complete and self-contained. Future phases are **optional** and depend on whether you find Julia useful:

- **Phase 2:** Rewrite count matrix assembly (Step 09) in Julia
  - Expected speedup: 5-10× faster than bash/awk
  - Better memory handling for large sample counts
  
- **Phase 3:** Replace DESeq2 R script with Julia statistical analysis
  - Requires careful validation against R results
  - More ambitious but potentially faster

- **Phase 4:** Julia pipeline orchestrator
  - Replace `run_full_pipeline.sh` with Julia script
  - Better dependency management and error handling

**Decision point:** Try Phase 1 on a few runs. If you like it and find the reports useful, consider Phase 2. If not, just keep using it as a validation tool!

## Questions?

- Julia not working? Check HPC documentation or contact cluster support
- Want to extend the QC? The script is well-commented and easy to modify
- Should you proceed to Phase 2? Only if you found Phase 1 genuinely helpful

---

**Remember:** Phase 1 is fully optional. Your pipeline works fine without it. This is just an enhancement to give you better visibility into your data quality and to test Julia integration with minimal risk.
