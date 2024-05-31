#!/bin/bash -eu

cd "$(dirname "$0")"

SRC_DIR=../data
DEST_DIR=../target_doc

CARGO_DIR=..
YAML_TO_JSON="$CARGO_DIR/target/release/yaml_to_json"
JSON_TO_MD="../bin/to_md.jq"

# 文書置き場のルートにある想定
CSS_FILENAME=moddl.css

for cmd in cargo jq pandoc; do
	if ! which "$cmd" > /dev/null; then
		echo "This script requires \"$cmd\" available as a command." >&2
		exit 1
	fi
done

# YAML → JSON 変換ツールを作っておく
pushd "$CARGO_DIR" > /dev/null
	cargo build --release
popd > /dev/null

# 出力先をクリア
if [ -d "$DEST_DIR" ]; then
	rm -rf "$DEST_DIR"
fi
mkdir -p "$DEST_DIR"

# ディレクトリを作る
pushd "$SRC_DIR" > /dev/null
	dirs="$(find . -type d)"
popd > /dev/null
pushd "$DEST_DIR" > /dev/null
	for dir in $dirs; do
		mkdir -p "$dir"
	done
popd > /dev/null

# ファイルを変換して出力

pushd "$SRC_DIR" > /dev/null
	files="$(find . -type f | sed 's|^\./||')"
popd > /dev/null

for file in $files; do
	inPath="$SRC_DIR/$file"
	ext="${file##*.}"
	case "$ext" in
		yaml | yml)
			# CSS のある場所の相対パスをがんばって求める
			cssDir="$(dirname "$(echo ${inPath#$SRC_DIR/})" | sed 's|[^/]*|..|g')"
			outPath="$DEST_DIR/${file%.*}.html"
			# TODO タイトルをつけないと警告が出るが、つけると h1 が 2 重になってしまう。どうしたものか
			# title="${file##*/}"
			title=

			"$YAML_TO_JSON" "$inPath" \
			| "$JSON_TO_MD" \
			| pandoc -f markdown -t html -s -c "$cssDir"/"$CSS_FILENAME" -F mermaid-filter --metadata title="$title" \
			> "$outPath"
		;;
		*)
			outPath="$DEST_DIR/$file"
			cp -p "$inPath" "$outPath"
		;;
	esac
done
