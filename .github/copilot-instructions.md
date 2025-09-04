# cargo-plan: Docker Friendly Build Plans for Cargo

cargo-plan is a Rust CLI tool that generates minimal buildable Cargo projects for Docker layer caching optimization. It creates dependency-only build plans that can be built separately from source code, solving Cargo's missing "build --dependencies-only" feature.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Initial Setup and Build Process
- Ensure Rust toolchain is available: `cargo --version && rustc --version`
- Build development version: `cargo build` -- takes 65 seconds on first build. NEVER CANCEL. Set timeout to 120+ seconds.
- Build release version: `cargo build --release` -- takes 50 seconds. NEVER CANCEL. Set timeout to 90+ seconds.
- Run tests: `cargo test` -- takes 2 seconds. Set timeout to 30+ seconds.
- Format code: `cargo fmt` -- takes <1 second.
- Run linter: `cargo clippy --all-targets --all-features -- -D warnings` -- takes 30 seconds. NEVER CANCEL. Set timeout to 60+ seconds.

### Core Tool Usage
The tool works as a cargo subcommand with three main operations:

1. **Create build plan**: `cargo run plan create`
   - Generates `cargo-plan.tar` containing minimal project structure
   - Takes <1 second to complete
   
2. **Build dependencies**: `cargo run plan build`
   - Builds dependencies from existing cargo-plan.tar
   - Takes <1 second to complete
   - Cleans up stub files after building dependencies
   
3. **Generate Dockerfile**: `cargo run plan generate-dockerfile`
   - Outputs optimized Dockerfile to stdout
   - Uses multi-stage build with dependency caching
   - Takes <3 seconds to complete
   - Redirect to file: `cargo run plan generate-dockerfile > Dockerfile.generated`

### Complete Workflow Example
```bash
# Create the build plan
cargo run plan create
# Build dependencies (in separate directory/container)
cargo run plan build
# Generate optimized Dockerfile
cargo run plan generate-dockerfile > Dockerfile.generated
```

## Validation

### End-to-End Testing Scenarios
ALWAYS run through this complete scenario after making changes to verify functionality:

1. **Test build plan creation and usage**:
   ```bash
   # Clean any existing plan files
   rm -f cargo-plan.tar
   
   # Create build plan
   cargo run plan create
   
   # Verify plan file was created
   ls -la cargo-plan.tar
   
   # Test building from plan
   cargo run plan build
   
   # Test Dockerfile generation
   cargo run plan generate-dockerfile | head -10
   
   # Clean up
   rm -f cargo-plan.tar
   ```

2. **Verify all builds and tests pass**:
   ```bash
   cargo build
   cargo build --release
   cargo test
   cargo fmt --check
   cargo clippy --all-targets --all-features -- -D warnings
   ```

### CI Requirements
The GitHub Actions workflow (.github/workflows/ci.yaml) requires:
- `cargo build --release --all-features` must succeed
- NO additional linting or formatting checks required for CI
- Build uses standard Rust stable toolchain

### Manual Validation Requirements
- ALWAYS test the complete create → build → generate workflow after code changes
- Verify generated Dockerfile contains expected multi-stage structure
- Confirm cargo-plan.tar file is created and can be consumed by build command
- Test with both development and release builds to ensure compatibility

## Common Tasks

### Repository Structure
```
cargo-plan/
├── .github/
│   └── workflows/ci.yaml          # GitHub Actions CI
├── src/
│   ├── lib.rs                     # Core functionality
│   └── main.rs                    # CLI interface
├── tests/                         # Integration tests (5 test cases)
├── Cargo.toml                     # Project manifest
├── Cargo.lock                     # Dependency lock
├── build.rs                       # Build script (vergen integration)
├── Dockerfile                     # Template Dockerfile using cargo-plan
└── README.md                      # Usage documentation
```

### Key Files to Review
- **src/main.rs**: CLI argument parsing and subcommand dispatch
- **src/lib.rs**: Core create/build logic, tar archive handling
- **tests/**: Integration tests covering different project structures
- **.github/workflows/ci.yaml**: CI pipeline (build --release --all-features only)
- **build.rs**: Version information generation using vergen-git2

### Development Commands
```bash
# Build and test cycle
cargo build && cargo test

# Full validation before committing
cargo build --release && cargo test && cargo fmt --check && cargo clippy --all-targets --all-features -- -D warnings

# Test tool functionality end-to-end
cargo run plan create && cargo run plan build && cargo run plan generate-dockerfile

# Generate optimized Dockerfile for project
cargo run plan generate-dockerfile > Dockerfile.new
```

### Performance Expectations
- **Initial cargo build**: 60-70 seconds (downloading/compiling dependencies)
- **Subsequent builds**: <5 seconds (incremental)
- **cargo build --release**: 45-50 seconds 
- **cargo test**: 1-2 seconds (5 tests total)
- **cargo clippy**: 25-30 seconds
- **Tool operations**: <1 second each (create/build/generate-dockerfile)

## Important Notes

### Build Dependencies
- Uses vergen-git2 for build-time version information
- Requires git repository context (build.rs may show warnings in temp directories)
- Standard Rust stable toolchain sufficient (no nightly features)

### Docker Integration
- Tool itself can be installed in Docker: `cargo install --git https://github.com/NathanHowell/cargo-plan`
- Generated Dockerfiles use multi-stage builds for optimal layer caching
- Template Dockerfile in repo demonstrates usage pattern

### Testing Infrastructure
- 5 integration tests covering different project structures (empty_lib, empty_app, non_standard, build_rs, self-test)
- Tests validate tar archive creation and project structure generation
- No unit tests in src/ files - functionality tested via integration tests

NEVER CANCEL long-running builds or clippy checks. Wait for completion to avoid partial compilation states.