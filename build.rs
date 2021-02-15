use std::error::Error;
use vergen::{gen, ConstantsFlags};

fn main() -> Result<(), Box<dyn Error>> {
    gen(ConstantsFlags::SHA)?;
    Ok(())
}
