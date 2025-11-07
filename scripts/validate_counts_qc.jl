#!/usr/bin/env julia
# =============================================================================
# RNA-seq Count Matrix QC and Validation Script
# Phase 1: Julia integration (low-risk QC addition)
# =============================================================================
# 
# This script performs quality control and validation on STAR count outputs
# and the combined count matrix. It does NOT replace existing pipeline steps,
# but provides additional validation and diagnostic information.
#
# Usage:
#   julia validate_counts_qc.jl /scratch/$USER/BHB_complete
#
# Requirements:
#   Julia packages: DataFrames, CSV, Statistics, Printf
#   Install with: julia -e 'using Pkg; Pkg.add(["DataFrames", "CSV", "Statistics"])'

using DataFrames
using CSV
using Statistics
using Printf

# =============================================================================
# Configuration
# =============================================================================

function parse_args()
    if length(ARGS) < 1
        println("Usage: julia validate_counts_qc.jl <base_directory>")
        println("Example: julia validate_counts_qc.jl /scratch/\$USER/BHB_complete")
        exit(1)
    end
    return ARGS[1]
end

BASE_DIR = parse_args()
ALIGN_DIR = joinpath(BASE_DIR, "04.Alignment")
COUNT_DIR = joinpath(BASE_DIR, "05.Counts")
QC_OUTPUT = joinpath(COUNT_DIR, "julia_qc_report.txt")

# Sample names (matching your pipeline)
SAMPLES = [
    "log_LM_3", "log_C_1", "log_C_2", "stat_N_1", "stat_N_2", "stat_N_3",
    "stat_B_1", "stat_B_2", "stat_B_3", "stat_L_1", "stat_L_2", "stat_M_1",
    "stat_M_3", "stat_BM_1", "stat_BM_2", "stat_BM_3", "stat_LM_1", "stat_LM_2",
    "stat_LM_3", "stat_C_1", "stat_C_2", "stat_C_3", "log_C_3", "stat_L_3",
    "stat_M_2", "log_N_1", "log_N_2", "log_N_3", "log_B_1", "log_B_2",
    "log_B_3", "log_L_1", "log_L_2", "log_L_3", "log_M_1", "log_M_2",
    "log_M_3", "log_BM_1", "log_BM_2", "log_BM_3", "log_LM_1", "log_LM_2"
]

# =============================================================================
# Validation Functions
# =============================================================================

"""
Check if all required directories exist
"""
function check_directories()
    println("\n" * "="^80)
    println("DIRECTORY VALIDATION")
    println("="^80)
    
    all_exist = true
    
    for (name, path) in [("Base", BASE_DIR), ("Alignment", ALIGN_DIR), ("Counts", COUNT_DIR)]
        exists = isdir(path)
        status = exists ? "✓" : "✗"
        println("  $status $name directory: $path")
        all_exist = all_exist && exists
    end
    
    return all_exist
end

"""
Validate individual STAR count files
"""
function validate_star_outputs()
    println("\n" * "="^80)
    println("STAR COUNT FILE VALIDATION")
    println("="^80)
    
    results = DataFrame(
        sample = String[],
        file_exists = Bool[],
        file_size = Int[],
        num_lines = Int[],
        num_genes = Int[],
        total_counts = Int[],
        ercc_genes = Int[],
        ercc_counts = Int[],
        status = String[]
    )
    
    for sample in SAMPLES
        count_file = joinpath(ALIGN_DIR, sample, "$(sample)_ReadsPerGene.out.tab")
        
        if !isfile(count_file)
            push!(results, (sample, false, 0, 0, 0, 0, 0, 0, "MISSING"))
            continue
        end
        
        # Read file and parse
        file_size = filesize(count_file)
        lines = readlines(count_file)
        num_lines = length(lines)
        
        # Skip first 4 lines (STAR stats: N_unmapped, N_multimapping, etc.)
        if num_lines <= 4
            push!(results, (sample, true, file_size, num_lines, 0, 0, 0, 0, "EMPTY"))
            continue
        end
        
        # Parse gene counts (column 2 = unstranded)
        gene_data = []
        ercc_count = 0
        ercc_reads = 0
        
        for line in lines[5:end]
            parts = split(line, '\t')
            if length(parts) >= 2
                gene_id = parts[1]
                count = parse(Int, parts[2])
                push!(gene_data, count)
                
                if startswith(gene_id, "ERCC-")
                    ercc_count += 1
                    ercc_reads += count
                end
            end
        end
        
        num_genes = length(gene_data)
        total_counts = sum(gene_data)
        status = "OK"
        
        # Flag potential issues
        if total_counts < 1_000_000
            status = "LOW_COUNTS"
        elseif total_counts > 100_000_000
            status = "HIGH_COUNTS"
        end
        
        push!(results, (sample, true, file_size, num_lines, num_genes, 
                       total_counts, ercc_count, ercc_reads, status))
    end
    
    return results
end

"""
Validate the combined count matrix
"""
function validate_count_matrix()
    println("\n" * "="^80)
    println("COUNT MATRIX VALIDATION")
    println("="^80)
    
    matrix_file = joinpath(COUNT_DIR, "counts_matrix_unstranded.txt")
    
    if !isfile(matrix_file)
        println("  ✗ Count matrix not found: $matrix_file")
        return nothing
    end
    
    println("  ✓ Count matrix found: $matrix_file")
    
    # Read matrix
    df = CSV.read(matrix_file, DataFrame; delim='\t')
    
    num_genes = nrow(df)
    num_samples = ncol(df) - 1  # Exclude GeneID column
    
    println("\n  Dimensions:")
    println("    - Genes: $num_genes")
    println("    - Samples: $num_samples")
    println("    - Expected samples: $(length(SAMPLES))")
    
    # Check sample names match
    sample_cols = names(df)[2:end]  # Skip GeneID column
    
    println("\n  Sample validation:")
    missing_samples = setdiff(SAMPLES, sample_cols)
    extra_samples = setdiff(sample_cols, SAMPLES)
    
    if isempty(missing_samples) && isempty(extra_samples)
        println("    ✓ All $(length(SAMPLES)) samples present and correct")
    else
        if !isempty(missing_samples)
            println("    ✗ Missing samples: $(join(missing_samples, ", "))")
        end
        if !isempty(extra_samples)
            println("    ⚠ Extra samples: $(join(extra_samples, ", "))")
        end
    end
    
    # Identify ERCC spike-ins
    gene_ids = df[!, 1]
    ercc_genes = filter(x -> startswith(string(x), "ERCC-"), gene_ids)
    yeast_genes = num_genes - length(ercc_genes)
    
    println("\n  Gene composition:")
    println("    - Yeast genes: $yeast_genes")
    println("    - ERCC spike-ins: $(length(ercc_genes))")
    
    # Calculate count statistics per sample
    println("\n  Count statistics by sample:")
    
    count_stats = DataFrame(
        sample = String[],
        total_counts = Int[],
        nonzero_genes = Int[],
        ercc_counts = Int[],
        ercc_percentage = Float64[]
    )
    
    for col in sample_cols
        counts = df[!, col]
        total = sum(counts)
        nonzero = count(x -> x > 0, counts)
        
        # ERCC counts
        ercc_mask = [startswith(string(g), "ERCC-") for g in gene_ids]
        ercc_total = sum(counts[ercc_mask])
        ercc_pct = 100.0 * ercc_total / total
        
        push!(count_stats, (col, total, nonzero, ercc_total, ercc_pct))
    end
    
    # Sort by total counts for easier inspection
    sort!(count_stats, :total_counts, rev=true)
    
    println("\n    Top 5 samples by count:")
    for i in 1:min(5, nrow(count_stats))
        row = count_stats[i, :]
        @printf("      %10s: %12s counts (%6d nonzero genes, ERCC: %5.2f%%)\n",
                row.sample, format_number(row.total_counts), row.nonzero_genes, row.ercc_percentage)
    end
    
    println("\n    Bottom 5 samples by count:")
    for i in max(1, nrow(count_stats)-4):nrow(count_stats)
        row = count_stats[i, :]
        @printf("      %10s: %12s counts (%6d nonzero genes, ERCC: %5.2f%%)\n",
                row.sample, format_number(row.total_counts), row.nonzero_genes, row.ercc_percentage)
    end
    
    # Overall statistics
    println("\n  Overall statistics:")
    @printf("    - Mean counts per sample: %s\n", format_number(Int(round(mean(count_stats.total_counts)))))
    @printf("    - Median counts per sample: %s\n", format_number(Int(median(count_stats.total_counts))))
    @printf("    - Min/Max counts: %s / %s\n", 
            format_number(minimum(count_stats.total_counts)),
            format_number(maximum(count_stats.total_counts)))
    @printf("    - Mean ERCC percentage: %.2f%%\n", mean(count_stats.ercc_percentage))
    
    return count_stats
end

"""
Cross-validate individual files against combined matrix
"""
function cross_validate(star_results, matrix_stats)
    println("\n" * "="^80)
    println("CROSS-VALIDATION: Individual Files vs. Matrix")
    println("="^80)
    
    if isnothing(matrix_stats)
        println("  ⚠ Cannot cross-validate: matrix not available")
        return
    end
    
    # Filter to only valid STAR results
    valid_star = filter(row -> row.status != "MISSING", star_results)
    
    discrepancies = 0
    
    for star_row in eachrow(valid_star)
        # Find matching row in matrix stats
        matrix_row_idx = findfirst(==(star_row.sample), matrix_stats.sample)
        
        if isnothing(matrix_row_idx)
            println("  ⚠ Sample $(star_row.sample) in STAR output but not in matrix")
            discrepancies += 1
            continue
        end
        
        matrix_row = matrix_stats[matrix_row_idx, :]
        
        # Compare total counts (should match exactly)
        if star_row.total_counts != matrix_row.total_counts
            println("  ✗ Count mismatch for $(star_row.sample):")
            println("      STAR file: $(format_number(star_row.total_counts))")
            println("      Matrix:    $(format_number(matrix_row.total_counts))")
            discrepancies += 1
        end
    end
    
    if discrepancies == 0
        println("  ✓ All samples match between individual files and matrix!")
    else
        println("\n  Total discrepancies: $discrepancies")
    end
end

"""
Generate summary report
"""
function generate_summary_report(star_results, matrix_stats)
    println("\n" * "="^80)
    println("SUMMARY REPORT")
    println("="^80)
    
    # File validation summary
    missing = count(row -> !row.file_exists, eachrow(star_results))
    empty = count(row -> row.status == "EMPTY", eachrow(star_results))
    low_counts = count(row -> row.status == "LOW_COUNTS", eachrow(star_results))
    ok = count(row -> row.status == "OK", eachrow(star_results))
    
    println("\n  Individual STAR files:")
    println("    ✓ OK: $ok")
    if missing > 0
        println("    ✗ Missing: $missing")
    end
    if empty > 0
        println("    ✗ Empty: $empty")
    end
    if low_counts > 0
        println("    ⚠ Low counts: $low_counts")
    end
    
    # Matrix summary
    if !isnothing(matrix_stats)
        println("\n  Combined matrix:")
        println("    ✓ Samples validated: $(nrow(matrix_stats))")
        
        # Check for outliers (using median absolute deviation)
        counts = matrix_stats.total_counts
        med = median(counts)
        mad_val = median(abs.(counts .- med))
        threshold = med - 3 * mad_val
        
        outliers = filter(row -> row.total_counts < threshold, matrix_stats)
        if nrow(outliers) > 0
            println("\n    ⚠ Potential outlier samples (unusually low counts):")
            for row in eachrow(outliers)
                @printf("      - %s: %s counts\n", row.sample, format_number(row.total_counts))
            end
        end
    end
    
    println("\n" * "="^80)
    println("QC VALIDATION COMPLETE")
    println("="^80)
end

"""
Format large numbers with commas
"""
function format_number(n::Int)
    s = string(n)
    # Add commas every 3 digits from the right
    parts = []
    while length(s) > 3
        pushfirst!(parts, s[end-2:end])
        s = s[1:end-3]
    end
    pushfirst!(parts, s)
    return join(parts, ",")
end

# =============================================================================
# Main Execution
# =============================================================================

function main()
    println("\n" * "="^80)
    println("RNA-SEQ COUNT MATRIX QC & VALIDATION")
    println("Julia-based Phase 1 Pipeline Addition")
    println("="^80)
    println("\nBase directory: $BASE_DIR")
    println("Output report: $QC_OUTPUT")
    
    # Redirect output to both console and file
    io = open(QC_OUTPUT, "w")
    
    try
        # Check directories
        if !check_directories()
            println("ERROR: Required directories not found")
            exit(1)
        end
        
        # Validate individual STAR outputs
        star_results = validate_star_outputs()
        
        # Print detailed results
        println("\n  Detailed results:")
        for row in eachrow(star_results)
            status_symbol = row.status == "OK" ? "✓" : 
                           row.status == "MISSING" ? "✗" : "⚠"
            @printf("    %s %-12s: %12s counts (%6d genes, %4d ERCC) [%s]\n",
                    status_symbol, row.sample, 
                    row.file_exists ? format_number(row.total_counts) : "N/A",
                    row.num_genes, row.ercc_genes, row.status)
        end
        
        # Save detailed STAR results
        star_csv = joinpath(COUNT_DIR, "julia_qc_star_validation.csv")
        CSV.write(star_csv, star_results)
        println("\n  ✓ Detailed results saved: $star_csv")
        
        # Validate combined matrix
        matrix_stats = validate_count_matrix()
        
        # Save matrix statistics
        if !isnothing(matrix_stats)
            matrix_csv = joinpath(COUNT_DIR, "julia_qc_matrix_stats.csv")
            CSV.write(matrix_csv, matrix_stats)
            println("  ✓ Matrix statistics saved: $matrix_csv")
        end
        
        # Cross-validation
        cross_validate(star_results, matrix_stats)
        
        # Summary report
        generate_summary_report(star_results, matrix_stats)
        
    finally
        close(io)
    end
    
    println("\n✓ QC report written to: $QC_OUTPUT")
    println("\nTo view the report: cat $QC_OUTPUT\n")
end

# Run main function
main()
