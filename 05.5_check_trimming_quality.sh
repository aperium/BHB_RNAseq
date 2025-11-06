#!/bin/bash
# Quality check script for RNAseq pipeline
# Compares raw and trimmed MultiQC outputs to ensure trimming was successful
# Exit code 0 = pass, exit code 1 = fail

set -euo pipefail

RAW_JSON="../03.FastQC_raw/multiqc_data/multiqc_data.json"
TRIMMED_JSON="../02.TrimmedData/fastqc/multiqc_data/multiqc_data.json"
LOG_DIR="../logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Remove any previous QC markers
rm -f "$LOG_DIR/qc_validation_passed.marker" "$LOG_DIR/qc_validation_failed.marker"

echo "=========================================="
echo "Trimming Quality Check"
echo "=========================================="
echo ""

# Check if files exist
if [[ ! -f "$RAW_JSON" ]]; then
    echo "ERROR: Raw MultiQC JSON not found at $RAW_JSON"
    exit 1
fi

if [[ ! -f "$TRIMMED_JSON" ]]; then
    echo "ERROR: Trimmed MultiQC JSON not found at $TRIMMED_JSON"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required but not installed"
    echo "Install with: module load jq  OR  brew install jq"
    exit 1
fi

echo "Analyzing quality metrics..."
echo ""

# Extract key metrics
RAW_READS=$(jq '.report_general_stats_data[0] | to_entries | map(.value.FastQC_raw.total_sequences // 0) | add' "$RAW_JSON")
TRIMMED_READS=$(jq '.report_general_stats_data[0] | to_entries | map(.value.FastQC_trimmed.total_sequences // 0) | add' "$TRIMMED_JSON")

RAW_AVG_LEN=$(jq '.report_general_stats_data[0] | to_entries | map(.value.FastQC_raw.avg_sequence_length // 0) | add / length' "$RAW_JSON")
TRIMMED_AVG_LEN=$(jq '.report_general_stats_data[0] | to_entries | map(.value.FastQC_trimmed.avg_sequence_length // 0) | add / length' "$TRIMMED_JSON")

RAW_FAILS=$(jq '.report_general_stats_data[0] | to_entries | map(.value.FastQC_raw.percent_fails // 0) | add / length' "$RAW_JSON")
TRIMMED_FAILS=$(jq '.report_general_stats_data[0] | to_entries | map(.value.FastQC_trimmed.percent_fails // 0) | add / length' "$TRIMMED_JSON")

# Calculate retention rate
RETENTION=$(echo "scale=2; $TRIMMED_READS * 100 / $RAW_READS" | bc)

echo "Metrics Summary:"
echo "  Raw reads:        $(printf "%'d" $RAW_READS)"
echo "  Trimmed reads:    $(printf "%'d" $TRIMMED_READS)"
echo "  Retention rate:   ${RETENTION}%"
echo ""
echo "  Raw avg length:   ${RAW_AVG_LEN} bp"
echo "  Trimmed avg len:  ${TRIMMED_AVG_LEN} bp"
echo ""
echo "  Raw % fails:      ${RAW_FAILS}%"
echo "  Trimmed % fails:  ${TRIMMED_FAILS}%"
echo ""

# Quality check thresholds
PASS=true

# Check 1: Retention rate should be >= 80%
if (( $(echo "$RETENTION < 80" | bc -l) )); then
    echo "❌ FAIL: Read retention ${RETENTION}% is below 80% threshold"
    PASS=false
else
    echo "✓ PASS: Read retention ${RETENTION}% is acceptable"
fi

# Check 2: Average length shouldn't drop by more than 20%
LENGTH_DROP=$(echo "scale=2; ($RAW_AVG_LEN - $TRIMMED_AVG_LEN) * 100 / $RAW_AVG_LEN" | bc)
if (( $(echo "$LENGTH_DROP > 20" | bc -l) )); then
    echo "❌ FAIL: Average length dropped by ${LENGTH_DROP}% (>20%)"
    PASS=false
else
    echo "✓ PASS: Average length drop ${LENGTH_DROP}% is acceptable"
fi

# Check 3: Failure rate should improve or stay similar (not increase by >5%)
FAIL_CHANGE=$(echo "scale=2; $TRIMMED_FAILS - $RAW_FAILS" | bc)
if (( $(echo "$FAIL_CHANGE > 5" | bc -l) )); then
    echo "❌ FAIL: Quality failures increased by ${FAIL_CHANGE}%"
    PASS=false
else
    echo "✓ PASS: Quality failure rate is acceptable"
fi

echo ""
echo "=========================================="
if [[ "$PASS" == true ]]; then
    echo "✓ OVERALL: QUALITY CHECK PASSED"
    echo "Pipeline can proceed to alignment"
    echo "=========================================="
    # Create marker file for successful QC validation
    touch "$LOG_DIR/qc_validation_passed.marker"
    exit 0
else
    echo "❌ OVERALL: QUALITY CHECK FAILED"
    echo "Review trimming parameters before proceeding"
    echo "=========================================="
    # Create marker file for failed QC validation
    touch "$LOG_DIR/qc_validation_failed.marker"
    exit 1
fi
