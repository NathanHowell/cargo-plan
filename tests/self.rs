pub mod util; // suppress linter warnings by making this public

use std::error::Error;
use std::path::PathBuf;
use std::{env, fs};
use util::round_up;

#[test]
fn process_self() -> Result<(), Box<dyn Error>> {
    let dst = tempfile::tempdir()?;
    // create a copy that excludes tests to prevent this from breaking each time a new one is added
    let src = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    fs::create_dir(dst.path().join("src"))?;

    let copy = |path: &str| fs::copy(src.join(path), dst.path().join(path));
    copy("Cargo.toml")?;
    copy("Cargo.lock")?;
    copy("build.rs")?;
    copy("src/main.rs")?;
    copy("src/lib.rs")?;
    let size = |path: &str| fs::metadata(src.join(path)).map(|m| round_up(m.len()));
    let size = size("Cargo.toml")? + size("Cargo.lock")?;

    let w = Vec::new();
    let w = cargo_plan::create(dst.path(), vec![], w)?;
    // 5 headers plus 2 `main` rust stubs plus 2 end-of-archive blocks
    assert_eq!(w.len() as u64, size + (9 * 512));

    Ok(())
}
