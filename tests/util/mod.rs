use std::io;
use std::io::Cursor;
use tar::Archive;

pub const fn round_up(value: u64) -> u64 {
    let x = 512 - (value % 512);
    value + x
}

pub fn paths(w: Vec<u8>) -> io::Result<Vec<String>> {
    let mut output = Vec::new();
    let mut archive = Archive::new(Cursor::new(w));
    for entry in archive.entries()? {
        let entry = entry?;
        output.push(entry.path()?.to_string_lossy().to_string())
    }

    Ok(output)
}
