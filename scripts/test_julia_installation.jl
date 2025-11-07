#!/usr/bin/env julia
# Quick test script to verify Julia installation and packages
# Run this to confirm Julia is working before using the main QC script

println("\n" * "="^60)
println("Julia Installation Test")
println("="^60)

# Check Julia version
println("\n1. Julia Version:")
println("   ", VERSION)

if VERSION >= v"1.9"
    println("   ✓ Version is recent (>= 1.9)")
else
    println("   ⚠ Consider upgrading Julia (current: $VERSION)")
end

# Test package loading
println("\n2. Testing Required Packages:")

packages = ["DataFrames", "CSV", "Statistics"]
all_ok = true

for pkg in packages
    try
        if pkg == "Statistics"
            # Statistics is a stdlib, just check it loads
            eval(Meta.parse("using $pkg"))
            println("   ✓ $pkg (stdlib)")
        else
            eval(Meta.parse("using $pkg"))
            # Get version info
            pkg_info = eval(Meta.parse("using Pkg; Pkg.dependencies()"))
            # Find the package UUID and get version
            println("   ✓ $pkg")
        end
    catch e
        println("   ✗ $pkg - ERROR: $e")
        all_ok = false
    end
end

# Test basic functionality
println("\n3. Testing Basic Functionality:")

try
    using DataFrames
    df = DataFrame(a = [1, 2, 3], b = ["x", "y", "z"])
    println("   ✓ Can create DataFrames")
catch e
    println("   ✗ DataFrame creation failed: $e")
    all_ok = false
end

try
    using Statistics
    data = [1, 2, 3, 4, 5]
    m = mean(data)
    println("   ✓ Can compute statistics (mean = $m)")
catch e
    println("   ✗ Statistics computation failed: $e")
    all_ok = false
end

# Test file I/O
println("\n4. Testing File I/O:")

try
    using CSV
    test_file = tempname() * ".csv"
    df = DataFrame(x = [1, 2, 3], y = [4, 5, 6])
    CSV.write(test_file, df)
    df2 = CSV.read(test_file, DataFrame)
    rm(test_file)
    println("   ✓ Can read/write CSV files")
catch e
    println("   ✗ File I/O failed: $e")
    all_ok = false
end

# Summary
println("\n" * "="^60)
if all_ok
    println("✓ ALL TESTS PASSED")
    println("\nYour Julia environment is ready for the RNA-seq pipeline!")
    println("You can now run: sbatch 09.5_validate_counts_qc.slurm")
else
    println("✗ SOME TESTS FAILED")
    println("\nPlease run the setup script:")
    println("  bash scripts/setup_julia_env.sh")
    println("\nOr install packages manually:")
    println("  julia -e 'using Pkg; Pkg.add([\"DataFrames\", \"CSV\"])'")
end
println("="^60 * "\n")

exit(all_ok ? 0 : 1)
