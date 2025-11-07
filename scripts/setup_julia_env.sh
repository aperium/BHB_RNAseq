#!/bin/bash
# =============================================================================
# Setup Julia Environment for RNA-seq Pipeline
# =============================================================================
#
# Run this ONCE on the HPC login node to install required Julia packages
# This ensures packages are pre-installed before running SLURM jobs
#
# Usage:
#   bash scripts/setup_julia_env.sh

set -e

echo "=========================================="
echo "Julia Environment Setup"
echo "=========================================="
echo ""

# Load Julia module
module load julia/1.11.6

echo "Julia version:"
julia --version
echo ""

# Check current package status
echo "Current Julia packages:"
julia -e 'using Pkg; Pkg.status()'
echo ""

# Install required packages
echo "Installing required packages for RNA-seq pipeline..."
echo "  - DataFrames: For tabular data manipulation"
echo "  - CSV: For reading/writing CSV and TSV files"
echo "  - Statistics: For statistical calculations"
echo ""

julia -e '
using Pkg

# Add required packages
packages = ["DataFrames", "CSV", "Statistics"]

println("Installing packages...")
for pkg in packages
    println("  → $pkg")
    Pkg.add(pkg)
end

println("\n✓ Package installation complete\n")

# Verify installation
println("Testing package imports...")
using DataFrames
using CSV
using Statistics

println("  ✓ DataFrames v$(Pkg.dependencies()[findfirst(p -> p.name == "DataFrames", Pkg.dependencies())].version)")
println("  ✓ CSV v$(Pkg.dependencies()[findfirst(p -> p.name == "CSV", Pkg.dependencies())].version)")
println("  ✓ Statistics (stdlib)")

println("\n✓ All packages successfully installed and tested")
'

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Your Julia environment is ready for the RNA-seq pipeline."
echo "You can now run: sbatch 09.5_validate_counts_qc.slurm"
echo ""
