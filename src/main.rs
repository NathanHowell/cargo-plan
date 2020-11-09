mod lib;
use clap::{clap_app, crate_authors, crate_description, crate_name, crate_version};
use std::error::Error;
use std::fs;
use std::fs::File;
use std::io::{BufReader, BufWriter};

fn main() -> Result<(), Box<dyn Error>> {
    let matches = clap_app!(myapp =>
        (version: crate_version!())
        (author: crate_authors!())
        (name: crate_name!())
        (about: crate_description!())
        (@setting SubcommandRequiredElseHelp)
        (@subcommand plan =>
             (@arg PLAN: --plan +takes_value default_value("cargo-plan.tar"))
             (@setting SubcommandRequiredElseHelp)
             (@subcommand generate =>
                 (@arg ARGS: +multiple +last)
             )
             (@subcommand build =>
                 (@arg ARGS: +multiple +last)
             )
        )
    )
    .get_matches();

    match matches.subcommand() {
        Some(("plan", plan)) => {
            let plan_path = plan.value_of("PLAN").unwrap();

            match plan.subcommand() {
                Some(("generate", args)) => {
                    let temp_dir = tempfile::TempDir::new()?;
                    let temp_file = temp_dir.path().join("plan.tar");
                    let archive = File::create(&temp_file)?;
                    let archive = BufWriter::new(archive);
                    let plan =
                        lib::generate(args.values_of_lossy("ARGS").unwrap_or_default(), archive)?;
                    drop(plan);
                    fs::rename(&temp_file, plan_path)?;
                }
                Some(("build", args)) => {
                    let archive = File::open(plan_path)?;
                    let archive = BufReader::new(archive);
                    lib::build(args.values_of_lossy("ARGS").unwrap_or_default(), archive)?;
                }
                _ => panic!(),
            }
        }
        _ => panic!(),
    }

    Ok(())
}