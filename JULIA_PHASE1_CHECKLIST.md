# Phase 1 Implementation Checklist

Use this checklist to verify Phase 1 is correctly set up and working.

## ✅ Files Created

- [x] `scripts/validate_counts_qc.jl` - Main QC validation script
- [x] `scripts/setup_julia_env.sh` - Package installation script  
- [x] `scripts/test_julia_installation.jl` - Installation verification
- [x] `09.5_validate_counts_qc.slurm` - SLURM job script
- [x] `JULIA_PHASE1_README.md` - Full documentation
- [x] `JULIA_PHASE1_SUMMARY.md` - Implementation summary
- [x] `JULIA_PHASE1_CHECKLIST.md` - This checklist
- [x] `QUICK_REFERENCE.md` - Updated with Julia QC section

## 📋 Pre-Flight Checklist

Before first use, complete these steps on the HPC:

### 1. Transfer Files to HPC

```bash
# From your local machine
cd /path/to/BHB_RNAseq
rsync -avz scripts/ $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/BHB_RNAseq/scripts/
rsync -avz *.slurm *.md $USER@login.hpc.virginia.edu:/scratch/$USER/BHB_complete/BHB_RNAseq/
```

**Or use Git:**
```bash
# Commit and push from local
git add scripts/*.jl scripts/*.sh *.slurm JULIA*.md
git commit -m "Add Julia Phase 1 QC validation"
git push

# Pull on HPC
ssh $USER@login.hpc.virginia.edu
cd /scratch/$USER/BHB_complete/BHB_RNAseq
git pull
```

### 2. Verify Julia Module Exists

```bash
# On HPC login node
ssh $USER@login.hpc.virginia.edu
module spider julia
```

**Expected output:**
```
  julia/1.11.6
```

✅ If you see Julia 1.11.6, proceed to step 3  
❌ If Julia not found, contact HPC support or skip Phase 1

### 3. Test Julia Installation

```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
module load julia/1.11.6
julia scripts/test_julia_installation.jl
```

**Expected output:**
```
============================================================
Julia Installation Test
============================================================

1. Julia Version:
   1.11.6
   ✓ Version is recent (>= 1.9)

2. Testing Required Packages:
   ✗ DataFrames - ERROR: ...
   ✗ CSV - ERROR: ...
   ✓ Statistics (stdlib)

3. Testing Basic Functionality:
   ...

============================================================
✗ SOME TESTS FAILED

Please run the setup script:
  bash scripts/setup_julia_env.sh
============================================================
```

This is **expected** if packages aren't installed yet. Proceed to step 4.

### 4. Install Julia Packages (One-time)

```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
bash scripts/setup_julia_env.sh
```

**Expected output:**
```
==========================================
Julia Environment Setup
==========================================

Julia version:
julia version 1.11.6

Installing packages...
  → DataFrames
  ...
  ✓ All packages successfully installed and tested

==========================================
Setup Complete!
==========================================
```

⏱️ Takes ~2-5 minutes depending on network speed

### 5. Verify Installation

```bash
julia scripts/test_julia_installation.jl
```

**Expected output (this time):**
```
============================================================
Julia Installation Test
============================================================

1. Julia Version:
   1.11.6
   ✓ Version is recent (>= 1.9)

2. Testing Required Packages:
   ✓ DataFrames
   ✓ CSV
   ✓ Statistics (stdlib)

3. Testing Basic Functionality:
   ✓ Can create DataFrames
   ✓ Can compute statistics (mean = 3.0)

4. Testing File I/O:
   ✓ Can read/write CSV files

============================================================
✓ ALL TESTS PASSED

Your Julia environment is ready for the RNA-seq pipeline!
You can now run: sbatch 09.5_validate_counts_qc.slurm
============================================================
```

✅ If all tests pass, you're ready!  
❌ If tests fail, check error messages or re-run setup

## 🧪 Test Run

Once setup is complete, test with your actual data:

### Option A: Test Run on Real Data (Recommended)

**Prerequisites:** Step 09 (`09_featureCounts.slurm`) must have completed

```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq

# Submit SLURM job
sbatch 09.5_validate_counts_qc.slurm

# Check job status
squeue -u $USER

# View output (after job completes)
cat ../logs/09.5_julia_qc_*.out

# View QC report
cat ../05.Counts/julia_qc_report.txt
```

**Expected results:**
- Job completes in 1-2 minutes
- No error messages in `.err` file
- QC report shows validation of all 42 samples
- CSV files created in `05.Counts/`

### Option B: Manual Test (For Debugging)

```bash
cd /scratch/$USER/BHB_complete/BHB_RNAseq
module load julia/1.11.6

# Run directly (requires count data to exist)
julia scripts/validate_counts_qc.jl /scratch/$USER/BHB_complete

# Check exit code
echo $?  # Should be 0 for success
```

## 🔍 Validation Checklist

After running the QC script, verify these outputs exist:

```bash
cd /scratch/$USER/BHB_complete/05.Counts

# Check files exist
ls -lh julia_qc_*

# Expected files:
# -rw-r--r-- 1 user group  25K Nov  6 15:30 julia_qc_report.txt
# -rw-r--r-- 1 user group 2.1K Nov  6 15:30 julia_qc_star_validation.csv
# -rw-r--r-- 1 user group 3.4K Nov  6 15:30 julia_qc_matrix_stats.csv
```

✅ All three files should exist  
✅ `julia_qc_report.txt` should be 20-30 KB  
✅ CSV files should have 42-43 rows (header + 42 samples)

## 🎯 Success Criteria

Phase 1 is successfully implemented if:

- ✅ Julia module loads without errors
- ✅ All required packages install successfully  
- ✅ Test script passes all checks
- ✅ QC script runs and completes without errors
- ✅ Output files are generated correctly
- ✅ QC report contains meaningful validation information
- ✅ You understand how to run the QC script when needed

## 🚫 Known Issues & Solutions

### Issue: "Module julia not found"
**Solution:** Julia not available on your cluster. Skip Phase 1 or request HPC support to install Julia.

### Issue: "Package installation failed"
**Solution:** 
```bash
# Try manual installation
julia -e 'using Pkg; Pkg.update(); Pkg.add(["DataFrames", "CSV"])'
```

### Issue: "Cannot find count files"
**Solution:** Make sure step 09 completed successfully and files are in `04.Alignment/SAMPLE/SAMPLE_ReadsPerGene.out.tab`

### Issue: "Permission denied"
**Solution:** Check you're in the correct directory and have write access to `05.Counts/`

### Issue: SLURM job fails immediately
**Solution:** Check error log:
```bash
cat ../logs/09.5_julia_qc_*.err
```

Common causes:
- Julia module name wrong (check with `module spider julia`)
- Base directory path incorrect
- Package dependencies not installed

## 📊 Understanding the Output

### Quick Check - Is Everything OK?

```bash
# View summary section only
grep -A 20 "SUMMARY REPORT" ../05.Counts/julia_qc_report.txt
```

Look for:
- ✅ **OK: 42** (all samples validated)
- ✅ **Missing: 0** (no missing files)
- ✅ **Cross-validation passed**

If you see warnings or errors:
- ⚠️ **Low counts: N** - Some samples have unusually low read counts
- ✗ **Missing: N** - Count files not found for some samples
- ⚠️ **Outlier samples** - Some samples significantly different from others

### Detailed Analysis

Open the full report:
```bash
less ../05.Counts/julia_qc_report.txt
```

Or import CSVs into R/Python for visualization:
```R
# In R
star_qc <- read.csv("../05.Counts/julia_qc_star_validation.csv")
matrix_stats <- read.csv("../05.Counts/julia_qc_matrix_stats.csv")

# Plot total counts per sample
barplot(matrix_stats$total_counts, names.arg=matrix_stats$sample, las=2)
```

## 🎉 Completion

Once all items above are checked off, Phase 1 is complete!

**Next Steps:**

- **Option 1:** Use as-is for ongoing QC validation ✅ **Recommended**
- **Option 2:** Proceed to Phase 2 (rewrite count matrix assembly)
- **Option 3:** Stop here - Phase 1 provides useful validation without further complexity

## 📚 Documentation Reference

- **Full Guide:** `JULIA_PHASE1_README.md`
- **Summary:** `JULIA_PHASE1_SUMMARY.md`  
- **Quick Reference:** `QUICK_REFERENCE.md` (Julia QC section)
- **Main Pipeline:** `README.md`

---

**Phase 1 Status:** ✅ Ready to use  
**Last Updated:** November 6, 2025
