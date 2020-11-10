mod lib;
use clap::{crate_authors, crate_description, crate_name, crate_version, App, AppSettings, Arg};
use std::error::Error;
use std::fs::File;
use std::io::{stdout, BufReader, BufWriter, Write};
use std::{env, fs};

fn app(name: &'static str) -> App {
    App::new(name)
        .version(crate_version!())
        .author(crate_authors!())
}

fn main() -> Result<(), Box<dyn Error>> {
    let plan_arg = Arg::new("PLAN")
        .long("plan")
        .takes_value(true)
        .default_value("cargo-plan.tar");
    let trailing_args = Arg::new("ARGS").multiple(true).last(true);
    let matches = app(crate_name!())
        .about(crate_description!())
        .bin_name("cargo")
        .setting(AppSettings::SubcommandRequiredElseHelp)
        .subcommand(
            app("plan")
                .about(crate_description!())
                .setting(AppSettings::SubcommandRequiredElseHelp)
                .subcommand(
                    app("create")
                        .about("Create a build plan")
                        .arg(&plan_arg)
                        .arg(&trailing_args),
                )
                .subcommand(
                    app("build")
                        .about("Execute a build plan")
                        .arg(plan_arg)
                        .arg(trailing_args),
                )
                .subcommand(
                    app("generate-dockerfile")
                        .about("Generate a Dockerfile")
                        .arg(Arg::new("DEST").short('f').long("file").default_value("-")),
                ),
        )
        .get_matches();

    match matches.subcommand() {
        Some(("plan", plan)) => match plan.subcommand() {
            Some(("create", args)) => {
                let plan_path = args.value_of("PLAN").unwrap();
                let temp_dir = tempfile::TempDir::new()?;
                let temp_file = temp_dir.path().join("plan.tar");
                let archive = File::create(&temp_file)?;
                let archive = BufWriter::new(archive);
                let plan = lib::create(
                    env::current_dir()?,
                    args.values_of_lossy("ARGS").unwrap_or_default(),
                    archive,
                )?;
                drop(plan);
                fs::rename(&temp_file, plan_path)?;
            }
            Some(("build", args)) => {
                let plan_path = args.value_of("PLAN").unwrap();
                let archive = File::open(plan_path)?;
                let archive = BufReader::new(archive);
                lib::build(
                    env::current_dir()?,
                    args.values_of_lossy("ARGS").unwrap_or_default(),
                    archive,
                )?;
            }
            Some(("generate-dockerfile", args)) => {
                let dest = args.value_of("DEST").unwrap();
                let archive = match dest {
                    "-" => Ok(Box::new(stdout()) as Box<dyn Write>),
                    _ => File::open(dest).map(|f| Box::new(f) as Box<dyn Write>),
                }?;
                let archive = BufWriter::new(archive);
                lib::generate_dockerfile(env::current_dir()?, archive)?;
            }
            _ => panic!(),
        },
        _ => panic!(),
    }

    Ok(())
}
