pub mod util; // suppress linter warnings by making this public

use std::env;
use std::error::Error;
use std::path::PathBuf;
use util::paths;

trait IsSorted {
    fn is_sorted(&self) -> bool;
}

impl<T: Clone + Ord> IsSorted for Vec<T> {
    fn is_sorted(&self) -> bool {
        // too bad std is_sorted is unstable...

        // not terribly efficient ;-)
        let mut sorted = self.to_vec();
        sorted.sort();
        self == &sorted
    }
}

#[test]
fn empty_app() -> Result<(), Box<dyn Error>> {
    let src = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let w = Vec::new();
    let w = cargo_plan::create(src.join("tests").join("empty_app"), vec![], w)?;
    assert_eq!(w.len() as u64, 512 * 8);

    let paths = paths(w)?;
    assert!(paths.is_sorted());
    assert_eq!(paths, ["Cargo.lock", "Cargo.toml", "src/main.rs"]);

    Ok(())
}

#[test]
fn empty_lib() -> Result<(), Box<dyn Error>> {
    let src = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let w = Vec::new();
    let w = cargo_plan::create(src.join("tests").join("empty_lib"), vec![], w)?;
    assert_eq!(w.len() as u64, 512 * 7);

    let paths = paths(w)?;
    assert!(paths.is_sorted());
    assert_eq!(paths, ["Cargo.lock", "Cargo.toml", "src/lib.rs"]);

    Ok(())
}

#[test]
fn non_standard_lib() -> Result<(), Box<dyn Error>> {
    let src = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let w = Vec::new();
    let w = cargo_plan::create(src.join("tests").join("non_standard"), vec![], w)?;
    assert_eq!(w.len() as u64, 512 * 7);

    let paths = paths(w)?;
    assert!(paths.is_sorted());
    assert_eq!(paths, ["Cargo.lock", "Cargo.toml", "lib.rs"]);

    Ok(())
}

#[test]
fn build_rs() -> Result<(), Box<dyn Error>> {
    let src = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let w = Vec::new();
    let w = cargo_plan::create(src.join("tests").join("build_rs"), vec![], w)?;
    assert_eq!(w.len() as u64, 512 * 9);

    let paths = paths(w)?;
    assert!(paths.is_sorted());
    assert_eq!(
        paths,
        ["Cargo.lock", "Cargo.toml", "build.rs", "src/lib.rs"]
    );

    Ok(())
}
