mod lib;
use clap::{crate_authors, crate_description, crate_name, crate_version, Arg, Command};
use std::error::Error;
use std::fs::File;
use std::io::{stdout, BufReader, BufWriter, Write};
use std::{env, fs};

fn app(name: &'static str) -> Command {
    Command::new(name)
        .version(crate_version!())
        .author(crate_authors!())
}

fn run_app() -> Result<(), Box<dyn Error>> {
    let plan_arg = Arg::new("PLAN")
        .short('f')
        .long("file")
        .value_name("FILE")
        .default_value("cargo-plan.tar");
    let trailing_args = Arg::new("ARGS")
        .num_args(0..)
        .last(true)
        .help("Additional arguments to pass to cargo");
    let matches = app(crate_name!())
        .about(crate_description!())
        .bin_name("cargo")
        .subcommand_required(true)
        .subcommand(
            app("plan")
                .about(crate_description!())
                .subcommand_required(true)
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
                let plan_path = args.get_one::<String>("PLAN").unwrap();
                let temp_dir = tempfile::TempDir::new()?;
                let temp_file = temp_dir.path().join("plan.tar");
                let archive = File::create(&temp_file)?;
                let archive = BufWriter::new(archive);
                let plan = lib::create(
                    env::current_dir()?,
                    args.get_many::<String>("ARGS")
                        .unwrap_or_default()
                        .map(|s| s.to_string())
                        .collect::<Vec<_>>(),
                    archive,
                )?;
                drop(plan);
                fs::rename(&temp_file, plan_path)?;
            }
            Some(("build", args)) => {
                let plan_path = args.get_one::<String>("PLAN").unwrap();
                let archive = File::open(plan_path)
                    .map_err(|e| format!("Failed to open {}: {}", plan_path, e))?;
                let archive = BufReader::new(archive);
                let working_directory = tempfile::TempDir::new()?;
                lib::build(
                    working_directory.path(),
                    args.get_many::<String>("ARGS")
                        .unwrap_or_default()
                        .map(|s| s.to_string())
                        .collect::<Vec<_>>(),
                    archive,
                )?;
            }
            Some(("generate-dockerfile", args)) => {
                let dest = args.get_one::<String>("DEST").unwrap();
                let archive = match dest.as_str() {
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

fn main() {
    std::process::exit(match run_app() {
        Ok(_) => 0,
        Err(err) => {
            eprintln!("error: {}", err);
            1
        }
    })
}
