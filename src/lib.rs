use cargo_metadata::{CrateType, Metadata, MetadataCommand, Package, PackageId, Target};
use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};
use std::convert::TryInto;
use std::env;
use std::fmt::{self, Display, Formatter};
use std::fs::File;
use std::hash::Hash;
use std::io::{self, Cursor, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use tar::Header;

#[derive(Debug)]
pub enum Error {
    FileExistsError(PathBuf),

    UnknownCrateTypeError {
        crate_type: Vec<CrateType>,
        name: String,
    },

    RelativePathError {
        path: PathBuf,
        base: PathBuf,
    },

    IoError(io::Error),

    MetadataError(cargo_metadata::Error),
}

impl Display for Error {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        match self {
            Error::FileExistsError(path) => write!(
                f,
                "The file {0:?} already exists, please rerun in an empty directory",
                path
            ),
            Error::UnknownCrateTypeError { crate_type, name } => {
                write!(f, "Unknown crate type {0:?} in {1}", crate_type, name)
            }
            Error::RelativePathError { path, base } => write!(
                f,
                "Failure calculating relative path between {0:?} and {1:?}",
                path, base
            ),
            Error::IoError(e) => e.fmt(f),
            Error::MetadataError(e) => e.fmt(f),
        }
    }
}

impl std::error::Error for Error {}

impl From<io::Error> for Error {
    fn from(e: io::Error) -> Self {
        Error::IoError(e)
    }
}

impl From<cargo_metadata::Error> for Error {
    fn from(e: cargo_metadata::Error) -> Self {
        Error::MetadataError(e)
    }
}

#[derive(Debug)]
pub(crate) struct Entry {
    pub header: tar::Header,
    pub data: Vec<u8>,
}

fn default_header() -> Header {
    let mut header = Header::new_gnu();
    header.set_mode(0o644);
    // some archive libraries fail with mtime==0
    header.set_mtime(1);
    header
}

fn diff_path<P: AsRef<Path>, B: AsRef<Path>>(path: P, base: B) -> Result<PathBuf, Error> {
    pathdiff::diff_paths(&path, &base).ok_or_else(|| Error::RelativePathError {
        base: base.as_ref().to_path_buf(),
        path: path.as_ref().to_path_buf(),
    })
}

impl Entry {
    const LIB_TYPES: &'static [&'static CrateType] = &[
        &CrateType::Lib,
        &CrateType::RLib,
        &CrateType::DyLib,
        &CrateType::CDyLib,
        &CrateType::StaticLib,
        &CrateType::ProcMacro,
    ];

    const BIN_TYPE: &'static CrateType = &CrateType::Bin;

    fn from_path<B: AsRef<Path>, P: Into<PathBuf>>(base_path: B, path: P) -> Result<Self, Error> {
        let path = path.into();
        let data = std::fs::File::open(&path)?;
        Entry::from_file(base_path, path, data)
    }

    fn from_file<B: AsRef<Path>, P: Into<PathBuf>>(
        base_path: B,
        path: P,
        mut file: File,
    ) -> Result<Self, Error> {
        let path = path.into();
        let mut header = default_header();
        let metadata = file.metadata()?;
        header.set_path(diff_path(path, base_path)?)?;
        header.set_size(metadata.len());
        header.set_cksum();
        let mut data = Vec::with_capacity(metadata.len().try_into().unwrap());
        file.read_to_end(&mut data)?;
        Ok(Entry { header, data })
    }

    fn from_bytes<P: Into<PathBuf>, V: Into<Vec<u8>>>(path: P, data: V) -> Result<Self, Error> {
        let path = path.into();
        let mut header = default_header();
        let data = data.into();
        header.set_path(path)?;
        header.set_size(data.len().try_into().unwrap());
        header.set_cksum();
        Ok(Entry { header, data })
    }

    fn from_target<B: AsRef<Path>, T: Into<Target>>(
        base_path: B,
        target: T,
    ) -> Result<Self, Error> {
        let target = target.into();
        let path = diff_path(&target.src_path, base_path)?;
        let name = target.name.clone();
        let types = target.crate_types.iter().collect::<HashSet<_>>();
        if types.contains(Self::BIN_TYPE) {
            Entry::from_bytes(path, b"fn main() {}".to_vec())
        } else if types.contains_any(Self::LIB_TYPES) {
            Entry::from_bytes(path, b"".to_vec())
        } else {
            Err(Error::UnknownCrateTypeError {
                name,
                crate_type: target.crate_types,
            })
        }
    }
}

trait ContainsAny<T> {
    fn contains_any(&self, slice: &[T]) -> bool;
}

impl<T: Eq + Hash> ContainsAny<T> for HashSet<T> {
    fn contains_any(&self, slice: &[T]) -> bool {
        slice.iter().any(|e| self.contains(e))
    }
}

fn workspace_packages(metadata: &Metadata) -> Vec<&Package> {
    let members = metadata.workspace_members.iter().collect::<HashSet<_>>();

    // collect all packages, ordered by package id
    let packages = metadata
        .packages
        .iter()
        .filter(move |p| members.contains(&p.id))
        .map(|p| (p.id.clone(), p))
        .collect::<BTreeMap<_, _>>();

    packages.values().copied().collect()
}

fn metadata_entries(metadata: Metadata) -> Result<Vec<Entry>, Error> {
    let root = &metadata.workspace_root;

    // start with the root Cargo.toml, this may optionally show up in workspace_packages too
    // so we will dedupe with a set
    let mut paths = HashSet::<PathBuf>::new();
    for path in &["./Cargo.toml", "./Cargo.lock"] {
        let path = root.join_os(path);
        if path.exists() {
            paths.insert(path);
        }
    }

    let packages = workspace_packages(&metadata);
    for package in &packages {
        paths.insert(package.manifest_path.to_path_buf().into());
    }

    let mut entries = Vec::new();
    for path in paths {
        entries.push(Entry::from_path(&root, path)?);
    }

    for package in packages {
        for target in &package.targets {
            entries.push(Entry::from_target(&root, target.clone())?);
        }
    }

    // sort entries so we have a deterministic output tar file
    entries.sort_by_cached_key(|e| {
        e.header
            .path()
            .expect("all entries to have a path")
            .to_path_buf()
    });

    Ok(entries)
}

pub fn create<P: Into<PathBuf>, W: Write>(
    path: P,
    args: Vec<String>,
    write: W,
) -> Result<W, Error> {
    let metadata = MetadataCommand::new()
        .other_options(args)
        .current_dir(path)
        .exec()?;
    let mut archive = tar::Builder::new(write);
    for entry in metadata_entries(metadata)? {
        archive.append(&entry.header, Cursor::new(entry.data))?;
    }
    archive.finish()?;
    let destination = archive.into_inner()?;
    Ok(destination)
}

pub fn unpack<P: Into<PathBuf>, R: Read + Seek>(dir: P, source: R) -> Result<R, Error> {
    let dir = dir.into();
    let mut archive = tar::Archive::new(source);
    for entry in archive.entries()? {
        let entry = entry?;
        let path = dir.join(entry.path()?);
        if path.exists() {
            return Err(Error::FileExistsError(path));
        }
    }

    let mut reader = archive.into_inner();
    reader.seek(SeekFrom::Start(0))?;
    let mut recipe = tar::Archive::new(reader);
    recipe.unpack(dir)?;

    Ok(recipe.into_inner())
}

fn packages_to_build(metadata: &Metadata, workspace_relative_path: &Path) -> Vec<String> {
    // build up a lookup table for dependencies
    let resolved = metadata
        .resolve
        .iter()
        .flat_map(|x| &x.nodes)
        .map(|x| (&x.id, &x.dependencies))
        .collect::<HashMap<_, _>>();

    // run a BFS over the dependency graph starting with our local packages
    let mut queue = metadata
        .packages
        .iter()
        .filter(|p| p.manifest_path.starts_with(workspace_relative_path))
        .map(|p| p.id.clone())
        .collect::<Vec<_>>();

    let mut flattened_deps = BTreeSet::<PackageId>::new();
    while let Some(package) = queue.pop() {
        if flattened_deps.insert(package.clone()) {
            queue.extend_from_slice(resolved.get(&package).unwrap().as_slice());
        }
    }

    flattened_deps
        .into_iter()
        .map(|pid| &metadata[&pid])
        .map(|pkg| format!("--package={}:{}", pkg.name, pkg.version))
        .collect::<Vec<_>>()
}

pub fn build<P: Into<PathBuf>, R: Read + Seek>(
    path: P,
    args: Vec<String>,
    source: R,
) -> Result<R, Error> {
    let path = path.into();
    let path = path.canonicalize()?;

    // if this is being run in an existing workspace we need to capture the target directory
    // and propagate this to other commands via environment variable
    let (target_dir, workspace_root) = MetadataCommand::new()
        .exec()
        .map(|metadata| (metadata.target_directory, metadata.workspace_root))
        .ok()
        .map_or((None, None), |(x, y)| (Some(x), Some(y)));

    let source = unpack(path.clone(), source)?;
    let metadata = MetadataCommand::new().current_dir(path.clone()).exec()?;

    // check to see if the user has overridden the CARGO_TARGET_DIR environment variable
    // or set the build.target-dir config somewhere, if not we will need to do this
    let current_dir = env::current_dir()?;
    let target_dir = if let Some(target_dir) = target_dir {
        target_dir.into()
    } else if let Ok(suffix) = metadata.target_directory.strip_prefix(&path) {
        current_dir.join(suffix)
    } else {
        current_dir.join("target")
    };
    env::set_var("CARGO_TARGET_DIR", target_dir.as_os_str());

    // also propagate the relative path to `cargo build`
    let workspace_relative_path = workspace_root
        .iter()
        .flat_map(|w| current_dir.strip_prefix(w))
        .map(|w| path.join(w))
        .next()
        .unwrap_or_else(|| path.clone());

    // TODO: figure out why this builds packages it shouldn't
    // e.g. `cargo build --package redox_syscall:0.1.57` fails with:
    // error[E0554]: `#![feature]` may not be used on the stable release channel
    // let build_args = packages_to_build(&metadata, &workspace_relative_path);

    let status = Command::new("cargo")
        .current_dir(&workspace_relative_path)
        .envs(env::vars())
        .arg("build")
        .args(&args)
        // .args(build_args)
        .status()?;
    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }

    let packages = workspace_packages(&metadata);

    let clean_args = packages
        .into_iter()
        .filter(|p| p.manifest_path.starts_with(&workspace_relative_path))
        .map(|p| format!("--package={}", p.name))
        .collect::<Vec<_>>();

    // we should always have at least one package to clean
    assert!(!clean_args.is_empty());

    let status = Command::new("cargo")
        .current_dir(path)
        .envs(env::vars())
        .arg("clean")
        .args(clean_args)
        .args(args)
        .status()?;
    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }

    Ok(source)
}

fn expand_template<'a>(template: &'a str, install: &'a str, copy: &'a str) -> String {
    let mut output = Vec::new();
    let mut f: Box<dyn Fn(&'a str) -> &'a str> = Box::new(|i| i);
    for line in template.lines() {
        if line.starts_with("### __BEGIN_install") {
            f = Box::new(|_| install);
        } else if line.starts_with("### __BEGIN_copy") {
            f = Box::new(|_| copy);
        } else if line.starts_with("### __END") {
            f = Box::new(|i| i);
        } else {
            output.push(f(line));
        }
    }

    output.join("\n") + "\n"
}

fn install_cmd() -> &'static str {
    concat!(
        "RUN cargo install --git https://github.com/NathanHowell/cargo-plan --rev ",
        env!("VERGEN_GIT_SHA"),
    )
}

fn copy_cmd(packages: &[&Package]) -> String {
    let base_path = PathBuf::from("/app/target/release");
    let targets = packages
        .iter()
        .flat_map(|p| &p.targets)
        .filter_map(|t| {
            if t.crate_types.contains(Entry::BIN_TYPE) {
                Some(base_path.join(&t.name))
            } else {
                None
            }
        })
        .collect::<Vec<_>>();
    let entrypoint = targets.get(0);
    let ambiguous = targets.len() > 1;
    let targets = format!(
        "COPY --from=builder [{}, \"./\"]",
        targets
            .iter()
            .map(|t| format!("\"{}\"", t.to_string_lossy()))
            .collect::<Vec<_>>()
            .join(", ")
    );

    let mut output = vec![targets];
    if let Some(entrypoint) = entrypoint {
        if ambiguous {
            output.push(
                "# NOTE: more than one binary target exists, this is an arbitrary entrypoint"
                    .into(),
            );
        }

        let entrypoint = entrypoint
            .file_name()
            .expect("binary targets are files")
            .to_string_lossy();
        output.push(format!("ENTRYPOINT [\"/app/{}\"]", entrypoint));
    }

    output.join("\n")
}

pub fn generate_dockerfile<P: Into<PathBuf>, W: Write>(
    path: P,
    mut destination: W,
) -> Result<(), Error> {
    let metadata = MetadataCommand::new().current_dir(path).exec()?;
    let packages = workspace_packages(&metadata);

    let template = expand_template(
        include_str!("../Dockerfile"),
        install_cmd(),
        copy_cmd(packages.as_slice()).as_str(),
    );

    destination.write_all(template.as_bytes())?;

    Ok(())
}
