use cargo_metadata::{Metadata, MetadataCommand, Target};
use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::convert::TryInto;
use std::fs::File;
use std::io;
use std::io::{Cursor, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use tar::Header;

#[derive(thiserror::Error, Debug)]
pub enum Error {
    #[error("File {0:?} already exists, please rerun in an empty directory")]
    FileExistsError(PathBuf),

    #[error("Unknown crate type {crate_type:?} in {name}")]
    UnknownCrateTypeError {
        crate_type: Vec<String>,
        name: String,
    },

    #[error("Failure calculating relative path between {path} and {base}")]
    RelativePathError { path: PathBuf, base: PathBuf },

    #[error(transparent)]
    IoError(io::Error),

    #[error(transparent)]
    MetadataError(cargo_metadata::Error),
}

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
        let path = diff_path(target.src_path, base_path)?;
        match target
            .crate_types
            .iter()
            .map(|p| p.as_str())
            .collect::<Vec<_>>()
            .as_slice()
        {
            ["bin"] => Entry::from_bytes(path, b"fn main() {}".to_vec()),
            ["lib"] => Entry::from_bytes(path, b"".to_vec()),
            crate_type => Err(Error::UnknownCrateTypeError {
                name: target.name,
                crate_type: crate_type.iter().map(|m| String::from(*m)).collect(),
            }),
        }
    }
}

pub(crate) fn metadata_entries(metadata: Metadata) -> Result<Vec<Entry>, Error> {
    let members = metadata
        .workspace_members
        .into_iter()
        .collect::<HashSet<_>>();

    let root = metadata.workspace_root;

    // collect all packages, ordered by package id
    let packages = metadata
        .packages
        .into_iter()
        .filter(move |p| members.contains(&p.id))
        .map(|p| (p.id.clone(), p))
        .collect::<BTreeMap<_, _>>();

    // start with the root Cargo.toml
    let mut manifests = BTreeSet::<PathBuf>::new();
    for path in &["./Cargo.toml", "./Cargo.lock"] {
        let path = root.join(path);
        if path.exists() {
            manifests.insert(path);
        }
    }

    for package in packages.values() {
        manifests.insert(package.manifest_path.to_path_buf());
    }

    let mut entries = Vec::new();
    for manifest in manifests {
        entries.push(Entry::from_path(&root, manifest)?);
    }

    for target in packages.into_iter().flat_map(|(_, p)| p.targets) {
        entries.push(Entry::from_target(&root, target)?);
    }

    Ok(entries)
}

pub fn generate<W: Write>(args: Vec<String>, write: W) -> Result<W, Error> {
    let metadata = MetadataCommand::new().other_options(args).exec()?;
    let mut archive = tar::Builder::new(write);
    for entry in metadata_entries(metadata)? {
        archive.append(&entry.header, Cursor::new(entry.data))?;
    }
    archive.finish()?;
    let destination = archive.into_inner()?;
    Ok(destination)
}

pub fn unpack<R: Read + Seek>(source: R) -> Result<R, Error> {
    let mut recipe = tar::Archive::new(source);
    for entry in recipe.entries()? {
        let entry = entry?;
        let path = entry.path()?;
        if path.exists() {
            return Err(Error::FileExistsError(path.to_path_buf()));
        }
    }

    let mut reader = recipe.into_inner();
    reader.seek(SeekFrom::Start(0))?;
    let mut recipe = tar::Archive::new(reader);
    recipe.unpack(".")?;

    Ok(recipe.into_inner())
}

pub fn build<R: Read + Seek>(build_args: Vec<String>, source: R) -> Result<R, Error> {
    let source = unpack(source)?;
    let metadata = cargo_metadata::MetadataCommand::new().exec()?;
    let packages = metadata
        .workspace_members
        .into_iter()
        .collect::<HashSet<_>>();
    let package_names = metadata
        .packages
        .into_iter()
        .filter_map(|p| {
            if packages.contains(&p.id) {
                Some(format!("--package={}", p.name))
            } else {
                None
            }
        })
        .collect::<Vec<_>>();

    let status = Command::new("cargo")
        .arg("build")
        .args(&build_args)
        .status()?;
    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }

    let status = Command::new("cargo")
        .arg("clean")
        .args(package_names)
        .args(build_args)
        .status()?;
    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }

    Ok(source)
}
