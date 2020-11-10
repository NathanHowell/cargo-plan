use std::error::Error;
use vergen::{generate_cargo_keys, ConstantsFlags};

fn main() -> Result<(), Box<dyn Error>> {
    generate_cargo_keys(ConstantsFlags::SHA)?;
    Ok(())
}
