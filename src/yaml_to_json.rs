use regex::Regex;
use yaml_validator::yaml_rust::Yaml;

pub fn yaml_to_json(yaml: &Yaml) -> String {
	let mut buf = String::new();
	build_json(&mut buf, yaml);
	buf
}

fn escape(str: &String) -> String {
	// 参照： https://www.crockford.com/mckeeman.html

	let str = Regex::new(r#"["\\/]"#).unwrap().replace_all(&str, r"\$0").to_string();
	// \b は単語境界に反応するらしく、思ってたのと違った。
	// Backspace が含まれることもないと考え、これ以上追わない
	// let str = Regex::new(r"\b").unwrap().replace_all(str, r"\b").to_string();
	let str = Regex::new(r"\f").unwrap().replace_all(&str, r"\f").to_string();
	let str = Regex::new(r"\n").unwrap().replace_all(&str, r"\n").to_string();
	let str = Regex::new(r"\r").unwrap().replace_all(&str, r"\r").to_string();
	let str = Regex::new(r"\t").unwrap().replace_all(&str, r"\t").to_string();
	// \uxxxx には対応しない
	
	str
}

fn build_json(buf: &mut String, yaml: &Yaml) {
	match yaml {
		Yaml::Real(v) => {
			buf.push_str(v.as_str())
		},
		Yaml::Integer(v) => {
			buf.push_str(v.to_string().as_str())
		},
		Yaml::String(v) => {
			buf.push_str(format!("\"{}\"", escape(v)).as_str());
		},
		Yaml::Boolean(v) => {
			buf.push_str(if *v { "true" } else { "false" });
		},
		Yaml::Array(v) => {
			buf.push('[');
			let mut first = true;
			for e in v {
				if ! first {
					buf.push(',');
				}
				build_json(buf, e);
				first = false;
			}
			buf.push(']');
		},
		Yaml::Hash(v) => {
			buf.push('{');
			let mut first = true;
			for k in v.keys() {
				// キーが文字列以外の場合（あるのか？）は考慮しない
				if let s @ Yaml::String(k) = k {
					if ! first {
						buf.push(',');
					}
					buf.push('"');
					buf.push_str(escape(k).as_str());
					buf.push_str("\":");
					build_json(buf, v.get(s).unwrap());
					first = false;
				}
			}
			buf.push('}');
		},
		Yaml::Alias(_) => {
			// 対応しない
		},
		Yaml::Null => {
			buf.push_str("null");
		},
		Yaml::BadValue => {
			// 対応しない
		},
	}
}
