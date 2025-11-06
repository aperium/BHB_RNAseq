# ERCC92 Spike-in Controls - Analysis Guide

## Overview

This pipeline includes **ERCC92 External RNA Controls Consortium spike-ins (Mix 1 only)** for improved normalization and quality control of your RNA-seq data.

## What are ERCC Spike-ins?

ERCC spike-ins are synthetic RNA transcripts of known sequence and concentration that are added to RNA samples before library preparation. They serve multiple purposes:

1. **Normalization**: Correct for technical variation in library preparation and sequencing
2. **Quality Control**: Assess the technical quality of the RNA-seq experiment
3. **Absolute Quantification**: Enable comparison of expression levels across samples
4. **Benchmark Performance**: Validate alignment, quantification, and DE analysis pipelines

## ERCC92 Mix 1 Specifications

- **92 synthetic polyadenylated transcripts**
- Lengths: 250-2,000 nucleotides
- Concentrations span **2^20-fold range** (0.125 to 60,000 attomoles/μl)
- Designed to mimic eukaryotic mRNA

## Pipeline Integration

### Step 1: Reference Preparation (Script 00)

The pipeline downloads and combines:
- *S. cerevisiae* genome (R64-1-1)
- *S. cerevisiae* annotation (GTF)
- **ERCC92 sequences (FASTA)**
- **ERCC92 annotation (GTF)**

Combined files:
- `combined_genome.fa` (yeast + ERCC)
- `combined_annotation.gtf` (yeast + ERCC)

### Step 2: Index Building (Script 03)

STAR index is built with the combined reference, allowing reads to align to both yeast genes and ERCC transcripts simultaneously.

### Step 3: Alignment (Script 04)

Reads align normally. ERCC reads will map to ERCC transcripts, counted alongside yeast genes.

### Step 4: Quantification (Script 06)

Gene counts include both:
- **Yeast genes** (~6,000-7,000 genes)
- **ERCC spike-ins** (92 controls)

### Step 5: DESeq2 Analysis with ERCC Normalization (Script 07)

The R script performs:

1. **Separates ERCC and gene counts**
2. **Calculates ERCC alignment statistics**
   - Total ERCC reads per sample
   - % of reads mapping to ERCC
   - Expected: 1-5% for typical spike-in amounts
3. **ERCC-based size factor calculation**
   - Uses ERCC counts to estimate technical variation
   - Applies these size factors to yeast gene normalization
4. **Comparison with standard normalization**
   - Saves both methods for comparison
5. **Differential expression** using ERCC-normalized counts

## Expected ERCC Behavior

### Good Quality Indicators:
- **Consistent ERCC %**: Similar across samples (1-5% typical)
- **Strong ERCC detection**: 80-92 ERCC transcripts detected
- **High correlation**: ERCC counts correlate with expected concentrations
- **Uniform size factors**: ERCC-based size factors are similar across samples

### Warning Signs:
- **Variable ERCC %**: Large variation suggests uneven spike-in addition
- **Low ERCC detection**: <70 transcripts may indicate degradation
- **Outlier samples**: Very different ERCC patterns from other samples
- **Size factor extremes**: Very large or small factors may indicate problems

## Output Files with ERCC Analysis

New outputs in `06.DESeq2_results/`:

1. **`ERCC_counts.csv`**
   - Raw counts for all 92 ERCC transcripts
   - Use for QC and validation

2. **`ERCC_alignment_stats.csv`**
   - Total counts per sample
   - ERCC counts per sample
   - % ERCC for each sample

3. **`ERCC_percentage_by_sample.pdf`**
   - Bar plot showing ERCC % across all samples
   - Red line = mean
   - Useful for identifying outliers

4. **`size_factor_comparison.csv`**
   - ERCC-based size factors
   - Standard DESeq2 size factors
   - Ratio between methods

5. **`size_factor_comparison.pdf`**
   - Scatter plot: ERCC vs standard normalization
   - Side-by-side bar plot comparison
   - Shows when ERCC correction differs from standard

## Interpreting ERCC Results

### Size Factor Comparison

If **ERCC ≈ Standard DESeq2**:
- Technical variation is minimal
- Standard normalization would be adequate
- ERCC confirms proper library prep

If **ERCC ≠ Standard DESeq2**:
- Technical variation present
- ERCC normalization is correcting for real batch effects
- Biological conclusions may differ between methods

### ERCC Percentage Across Samples

**Uniform (low CV%)**:
- Good quality control
- Consistent spike-in addition
- Reliable normalization

**Variable (high CV%)**:
- Investigate sample handling
- Check for pipetting errors
- May need to exclude outliers

## Advantages of ERCC Normalization

1. **Corrects for total RNA differences**
   - Treatments may affect total RNA content
   - ERCC normalizes to spike-in amount, not total library size

2. **Independent of biological changes**
   - Standard normalization assumes most genes unchanged
   - ERCC is unaffected by global transcriptional changes

3. **Validates technical quality**
   - Known input provides ground truth
   - Detects library prep failures

4. **Cross-study comparison**
   - Enables comparing experiments with different depths
   - Absolute quantification possible

## When to Use Standard vs ERCC Normalization

### Prefer ERCC normalization when:
- Treatments expected to cause **global expression changes**
- Your treatments (BHB, acac, mes, CR) may affect:
  - Total transcription rates
  - Cell size
  - RNA content per cell
- Comparing samples with different **total RNA amounts**
- Need **absolute quantification**

### Standard normalization may suffice when:
- ERCC % is very uniform across samples
- Size factors are nearly identical between methods
- Biological effects are gene-specific, not global

## Troubleshooting ERCC Issues

### Low ERCC Detection (<70 transcripts)

**Possible causes:**
- RNA degradation
- Low spike-in concentration
- Alignment issues

**Solutions:**
- Check RNA quality metrics
- Verify spike-in was added
- Check ERCC alignment rates in MultiQC

### High ERCC Percentage (>10%)

**Possible causes:**
- Too much spike-in added
- Low sample RNA concentration
- Sample degradation

**Solutions:**
- Reduce spike-in volume
- Check RNA quantification
- Re-extract problematic samples

### Inconsistent ERCC Across Samples

**Possible causes:**
- Pipetting error during spike-in addition
- Uneven mixing
- Batch effects

**Solutions:**
- Review sample handling protocols
- Check for processing batches
- Consider removing outliers

### ERCC and Standard Normalization Highly Divergent

**Interpretation:**
- Treatments cause **large global changes**
- Total RNA content differs between conditions
- ERCC normalization is **correcting real biology**

**Action:**
- Use ERCC normalization for main analysis
- Report both methods in supplementary materials
- Discuss global transcriptional effects

## Quality Control Checklist

After running the pipeline, check:

- [ ] **ERCC alignment %**: 1-5% per sample
- [ ] **CV of ERCC %**: <20% across samples
- [ ] **ERCC transcripts detected**: >80 out of 92
- [ ] **Size factor correlation**: ERCC vs standard plotted
- [ ] **Outlier samples**: Any samples with abnormal ERCC patterns?
- [ ] **PCA with ERCC**: Do samples cluster by biology or ERCC %?

## Additional ERCC Analyses (Optional)

### 1. ERCC Correlation Analysis

```R
# Load ERCC expected concentrations
ercc_info <- read.csv("ERCC_concentrations_Mix1.csv")

# Correlate observed vs expected
library(ggplot2)
for (sample in colnames(ercc_counts)) {
    plot_data <- merge(ercc_info, 
                       data.frame(ERCC_ID = rownames(ercc_counts),
                                  Observed = ercc_counts[, sample]),
                       by = "ERCC_ID")
    
    ggplot(plot_data, aes(x = log2(Expected_concentration), 
                          y = log2(Observed + 1))) +
        geom_point() +
        geom_smooth(method = "lm") +
        ggtitle(paste("ERCC Correlation:", sample))
}
```

### 2. Technical vs Biological Variation

```R
# Use ERCC to estimate technical noise floor
ercc_cv <- apply(ercc_counts, 1, function(x) sd(x) / mean(x))

# Compare to gene CVs
gene_cv <- apply(normalized_counts, 1, function(x) sd(x) / mean(x))

# Genes with CV > ERCC CV are likely biologically variable
```

### 3. Fold-Change Accuracy

```R
# ERCC Mix 1 vs Mix 2 (if you used both)
# Expected fold-changes are known
# Compare observed vs expected to validate DE pipeline
```

## References

1. **ERCC RNA Spike-In Control Mixes** - Thermo Fisher Scientific
2. **Baker et al. (2005)** - The External RNA Controls Consortium
3. **Jiang et al. (2011)** - Synthetic spike-in standards for RNA-seq experiments
4. **SEQC/MAQC-III Consortium (2014)** - A comprehensive assessment of RNA-seq accuracy

## Summary

ERCC spike-ins provide:
- ✅ Robust normalization for global expression changes
- ✅ Quality control metrics for technical performance
- ✅ Validation of bioinformatics pipeline
- ✅ Confidence in differential expression results

Your pipeline now includes all ERCC handling automatically!
