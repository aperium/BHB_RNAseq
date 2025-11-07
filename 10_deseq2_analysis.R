#!/usr/bin/env Rscript
# DESeq2 differential expression analysis for BHB RNA-seq project
# Includes ERCC92 spike-in normalization
# Run this script on the HPC after transferring count matrix

# Load required libraries
suppressPackageStartupMessages({
    library(DESeq2)
    library(ggplot2)
    library(pheatmap)
    library(RColorBrewer)
    library(dplyr)
    library(EnhancedVolcano)
})

# Set working directory - using environment variable for portability
user_name <- Sys.getenv("USER")
base_dir <- file.path("/scratch", user_name, "BHB_complete")
setwd(file.path(base_dir, "06.Counts"))

# Create output directory
dir.create("../07.DESeq2_results", showWarnings = FALSE)

# Load count matrix
cat("Loading count matrix...\n")
counts <- read.table("counts_matrix_unstranded.txt", 
                     header = TRUE, 
                     row.names = 1, 
                     sep = "\t")

# Remove first 4 rows if they contain STAR stats (N_unmapped, etc.)
if (any(grepl("^N_", rownames(counts)[1:4]))) {
    counts <- counts[-(1:4), ]
}

# ========== Separate ERCC and Gene Counts ==========
cat("Identifying ERCC spike-in controls...\n")

# ERCC spike-ins are identified by "ERCC-" prefix in gene names
ercc_genes <- grep("^ERCC-", rownames(counts), value = TRUE)
yeast_genes <- setdiff(rownames(counts), ercc_genes)

cat(sprintf("  ERCC spike-ins detected: %d\n", length(ercc_genes)))
cat(sprintf("  Yeast genes: %d\n", length(yeast_genes)))

# Separate count matrices
ercc_counts <- counts[ercc_genes, , drop = FALSE]
yeast_counts <- counts[yeast_genes, , drop = FALSE]

# Save ERCC counts separately for QC
write.csv(ercc_counts, "../07.DESeq2_results/ERCC_counts.csv", quote = FALSE)

# Calculate ERCC alignment statistics
ercc_totals <- colSums(ercc_counts)
gene_totals <- colSums(yeast_counts)
total_counts <- colSums(counts)
ercc_percentage <- 100 * ercc_totals / total_counts

ercc_stats <- data.frame(
    Sample = names(ercc_totals),
    Total_counts = total_counts,
    Yeast_counts = gene_totals,
    ERCC_counts = ercc_totals,
    ERCC_percentage = ercc_percentage
)
write.csv(ercc_stats, "../07.DESeq2_results/ERCC_alignment_stats.csv", 
          row.names = FALSE, quote = FALSE)

cat("\nERCC Alignment Summary:\n")
cat(sprintf("  Mean ERCC reads per sample: %.0f (%.2f%%)\n", 
            mean(ercc_totals), mean(ercc_percentage)))
cat(sprintf("  Range: %.2f%% - %.2f%%\n", 
            min(ercc_percentage), max(ercc_percentage)))

# Plot ERCC percentages
pdf("../07.DESeq2_results/ERCC_percentage_by_sample.pdf", width = 12, height = 6)
par(mar = c(10, 4, 4, 2))
barplot(ercc_percentage, 
        las = 2, 
        names.arg = names(ercc_percentage),
        main = "ERCC Spike-in Percentage by Sample",
        ylab = "% of Total Reads",
        col = "steelblue")
abline(h = mean(ercc_percentage), col = "red", lty = 2, lwd = 2)
legend("topright", legend = sprintf("Mean: %.2f%%", mean(ercc_percentage)), 
       col = "red", lty = 2, lwd = 2)
dev.off()

# Use yeast genes only for main analysis
counts <- yeast_counts

# Load sample metadata
cat("Loading sample metadata...\n")
metadata <- read.csv(file.path(base_dir, "BHB_RNAseq", "experimental_design.csv"), 
                     header = TRUE)

# Ensure sample names match
metadata$Sample <- gsub("-", "_", metadata$Sample)
rownames(metadata) <- metadata$Sample

# Reorder counts to match metadata
counts <- counts[, metadata$Sample]

# Check that all samples match
stopifnot(all(colnames(counts) == metadata$Sample))

cat(sprintf("Loaded %d genes and %d samples\n", nrow(counts), ncol(counts)))

# Convert counts to integer matrix
counts <- as.matrix(counts)
mode(counts) <- "integer"

# Create DESeq2 dataset
# Design: test for effects of phase, treatment, and their interaction
cat("Creating DESeqDataSet...\n")
dds <- DESeqDataSetFromMatrix(
    countData = counts,
    colData = metadata,
    design = ~ phase + treatment + phase:treatment
)

# Pre-filtering: remove genes with very low counts
keep <- rowSums(counts(dds)) >= 10
dds <- dds[keep, ]
cat(sprintf("Retained %d genes after filtering\n", sum(keep)))

# ========== ERCC-based Normalization ==========
cat("\nApplying ERCC-based size factors for normalization...\n")

# Create DESeq2 object with ERCC counts for normalization
# This uses ERCC spike-ins to calculate size factors
ercc_dds <- DESeqDataSetFromMatrix(
    countData = ercc_counts,
    colData = metadata,
    design = ~ 1
)

# Estimate size factors from ERCC spike-ins
ercc_dds <- estimateSizeFactors(ercc_dds)
ercc_size_factors <- sizeFactors(ercc_dds)

cat("ERCC-based size factors:\n")
print(round(ercc_size_factors, 3))

# Apply ERCC size factors to the main dataset
sizeFactors(dds) <- ercc_size_factors

# Also save standard DESeq2 size factors for comparison
dds_standard <- estimateSizeFactors(dds)
standard_size_factors <- sizeFactors(dds_standard)

# Compare normalization methods
size_factor_comparison <- data.frame(
    Sample = names(ercc_size_factors),
    ERCC_based = ercc_size_factors,
    Standard_DESeq2 = standard_size_factors,
    Ratio = ercc_size_factors / standard_size_factors
)
write.csv(size_factor_comparison, 
          "../07.DESeq2_results/size_factor_comparison.csv",
          row.names = FALSE, quote = FALSE)

# Plot comparison
pdf("../07.DESeq2_results/size_factor_comparison.pdf", width = 10, height = 5)
par(mfrow = c(1, 2))

plot(standard_size_factors, ercc_size_factors,
     xlab = "Standard DESeq2 Size Factors",
     ylab = "ERCC-based Size Factors",
     main = "Size Factor Comparison",
     pch = 19, col = "steelblue")
abline(0, 1, col = "red", lty = 2, lwd = 2)
legend("topleft", legend = "y = x", col = "red", lty = 2, lwd = 2)

barplot(rbind(standard_size_factors, ercc_size_factors),
        beside = TRUE,
        las = 2,
        col = c("coral", "steelblue"),
        main = "Size Factors by Method",
        ylab = "Size Factor",
        names.arg = rep("", length(ercc_size_factors)))
legend("topright", legend = c("Standard", "ERCC-based"), 
       fill = c("coral", "steelblue"))
dev.off()

cat("\nUsing ERCC-based normalization for downstream analysis.\n")
cat("Standard DESeq2 normalization saved for comparison.\n\n")

# Run DESeq2 with ERCC-normalized size factors
cat("Running DESeq2 analysis with ERCC normalization...\n")
dds <- estimateDispersions(dds)
dds <- nbinomWaldTest(dds)

# Save DESeq2 object
saveRDS(dds, "../07.DESeq2_results/dds.rds")

# Get normalized counts
normalized_counts <- counts(dds, normalized = TRUE)
write.csv(normalized_counts, 
          "../07.DESeq2_results/normalized_counts.csv",
          quote = FALSE)

# ========== QC Plots ==========
cat("Generating QC plots...\n")

# VST transformation for visualization
vsd <- vst(dds, blind = FALSE)

# PCA plot
pdf("../07.DESeq2_results/PCA_plot.pdf", width = 10, height = 8)
pcaData <- plotPCA(vsd, intgroup = c("phase", "treatment"), returnData = TRUE)
percentVar <- round(100 * attr(pcaData, "percentVar"))
ggplot(pcaData, aes(PC1, PC2, color = treatment, shape = phase)) +
    geom_point(size = 4) +
    xlab(paste0("PC1: ", percentVar[1], "% variance")) +
    ylab(paste0("PC2: ", percentVar[2], "% variance")) +
    theme_bw() +
    ggtitle("PCA of Samples")
dev.off()

# Sample distance heatmap
pdf("../07.DESeq2_results/sample_distance_heatmap.pdf", width = 12, height = 10)
sampleDists <- dist(t(assay(vsd)))
sampleDistMatrix <- as.matrix(sampleDists)
rownames(sampleDistMatrix) <- paste(vsd$phase, vsd$treatment, vsd$replicate, sep = "_")
colnames(sampleDistMatrix) <- NULL
colors <- colorRampPalette(rev(brewer.pal(9, "Blues")))(255)
pheatmap(sampleDistMatrix,
         clustering_distance_rows = sampleDists,
         clustering_distance_cols = sampleDists,
         col = colors,
         main = "Sample-to-Sample Distances")
dev.off()

# ========== Differential Expression Comparisons ==========
cat("Performing differential expression comparisons...\n")

# Function to extract and save results
extract_results <- function(dds, contrast, comparison_name, alpha = 0.05) {
    cat(sprintf("  %s...\n", comparison_name))
    
    res <- results(dds, contrast = contrast, alpha = alpha)
    res_ordered <- res[order(res$padj), ]
    
    # Summary
    cat(sprintf("    Significant genes (padj < %.2f): %d\n", 
                alpha, sum(res$padj < alpha, na.rm = TRUE)))
    
    # Save results
    write.csv(as.data.frame(res_ordered), 
              sprintf("../07.DESeq2_results/DESeq2_%s.csv", comparison_name),
              quote = FALSE)
    
    # MA plot
    pdf(sprintf("../07.DESeq2_results/MA_plot_%s.pdf", comparison_name), 
        width = 8, height = 6)
    plotMA(res, main = comparison_name, ylim = c(-5, 5))
    dev.off()
    
    # Volcano plot (if EnhancedVolcano is available)
    if (requireNamespace("EnhancedVolcano", quietly = TRUE)) {
        pdf(sprintf("../07.DESeq2_results/volcano_%s.pdf", comparison_name),
            width = 10, height = 8)
        print(EnhancedVolcano(res,
                             lab = rownames(res),
                             x = 'log2FoldChange',
                             y = 'padj',
                             title = comparison_name,
                             pCutoff = alpha,
                             FCcutoff = 1.0))
        dev.off()
    }
    
    return(res)
}

# Main comparisons within each phase
# Stationary phase comparisons
res_stat_B_vs_N <- extract_results(dds, 
    contrast = c("treatment", "B", "N"),
    comparison_name = "stat_BHB_vs_nonrestricted")

res_stat_L_vs_N <- extract_results(dds, 
    contrast = c("treatment", "L", "N"),
    comparison_name = "stat_acac_vs_nonrestricted")

res_stat_M_vs_N <- extract_results(dds, 
    contrast = c("treatment", "M", "N"),
    comparison_name = "stat_mes_vs_nonrestricted")

res_stat_C_vs_N <- extract_results(dds, 
    contrast = c("treatment", "C", "N"),
    comparison_name = "stat_control_vs_nonrestricted")

# Log phase comparisons
res_log_B_vs_N <- extract_results(dds, 
    contrast = c("treatment", "B", "N"),
    comparison_name = "log_BHB_vs_nonrestricted")

res_log_L_vs_N <- extract_results(dds, 
    contrast = c("treatment", "L", "N"),
    comparison_name = "log_acac_vs_nonrestricted")

res_log_M_vs_N <- extract_results(dds, 
    contrast = c("treatment", "M", "N"),
    comparison_name = "log_mes_vs_nonrestricted")

res_log_C_vs_N <- extract_results(dds, 
    contrast = c("treatment", "C", "N"),
    comparison_name = "log_control_vs_nonrestricted")

# Phase effect for each treatment
res_phase_N <- extract_results(dds,
    contrast = c("phase", "stat", "log"),
    comparison_name = "stat_vs_log_in_nonrestricted")

res_phase_B <- extract_results(dds,
    contrast = c("phase", "stat", "log"),
    comparison_name = "stat_vs_log_in_BHB")

# Create summary table
cat("Creating summary table of all comparisons...\n")
comparisons <- c(
    "stat_BHB_vs_nonrestricted",
    "stat_acac_vs_nonrestricted",
    "stat_mes_vs_nonrestricted",
    "stat_control_vs_nonrestricted",
    "log_BHB_vs_nonrestricted",
    "log_acac_vs_nonrestricted",
    "log_mes_vs_nonrestricted",
    "log_control_vs_nonrestricted",
    "stat_vs_log_in_nonrestricted",
    "stat_vs_log_in_BHB"
)

summary_df <- data.frame(
    Comparison = comparisons,
    Total_genes = nrow(dds),
    DE_genes_padj05 = NA,
    Upregulated = NA,
    Downregulated = NA
)

# Fill in summary
result_objects <- list(
    res_stat_B_vs_N, res_stat_L_vs_N, res_stat_M_vs_N, res_stat_C_vs_N,
    res_log_B_vs_N, res_log_L_vs_N, res_log_M_vs_N, res_log_C_vs_N,
    res_phase_N, res_phase_B
)

for (i in seq_along(result_objects)) {
    res <- result_objects[[i]]
    summary_df$DE_genes_padj05[i] <- sum(res$padj < 0.05, na.rm = TRUE)
    summary_df$Upregulated[i] <- sum(res$padj < 0.05 & res$log2FoldChange > 0, na.rm = TRUE)
    summary_df$Downregulated[i] <- sum(res$padj < 0.05 & res$log2FoldChange < 0, na.rm = TRUE)
}

write.csv(summary_df, 
          "../07.DESeq2_results/DE_summary.csv",
          row.names = FALSE,
          quote = FALSE)

print(summary_df)

cat("\nDESeq2 analysis complete!\n")
cat("Results saved to: ", output_dir, "\n", sep="")
