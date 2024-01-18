mod yaml_to_json;

use std::io::{self, Read};
use std::{fs::File};

use yaml_validator::yaml_rust::YamlLoader;

type IoResult<T> = Result<T, io::Error>;

fn read_file(path: &str) -> IoResult<String> {
	let mut file = File::open(path) ?;
	let mut content = String::new();
	file.read_to_string(&mut content) ?;
	Ok(content)
}

fn main() -> IoResult<()> {
	// TODO エラー処理
	let path = std::env::args().nth(1).unwrap();
	let docs = YamlLoader::load_from_str(read_file(path.as_str())?.as_str()).unwrap();
	let doc = &docs[0];

	println!("{}", yaml_to_json::yaml_to_json(doc));

	Ok(())
}
