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

function transform {
	local inDir="$1"
	local outDir="$2"
	local callback="$3"

	# 出力先をクリア
	# 差分ビルドのためクリアしない
	# if [ -d "$outDir" ]; then
	# 	rm -rf "$outDir"
	# fi
	mkdir -p "$outDir"

	# ディレクトリを作る
	pushd "$inDir" > /dev/null
		dirs="$(find . -type d)"
	popd > /dev/null
	pushd "$outDir" > /dev/null
		for dir in $dirs; do
			mkdir -p "$dir"
		done
	popd > /dev/null

	# ファイルを変換して出力

	pushd "$inDir" > /dev/null
		files="$(find . -type f | sed 's|^\./||')"
	popd > /dev/null

	for file in $files; do
		echo "$file"
		# inPath="$inDir/$file"
		$callback "$inDir" "$file" "$outDir"
	done
}

function yamlToHtmlCallback {
	local inDir="$1"
	local file="$2"
	local outDir="$3"

	inPath="$inDir/$file"
	ext="${file##*.}"
	case "$ext" in
		yaml | yml)
			outPath="$outDir/${file%.*}.html"
			if [ ! "$inPath" -nt "$outPath" ]; then return; fi

			# CSS のある場所の相対パスをがんばって求める
			cssDir="$(dirname "$(echo ${inPath#$inDir/})" | sed 's|[^/]*|..|g')"
			# TODO タイトルをつけないと警告が出るが、つけると h1 が 2 重になってしまう。どうしたものか
			# title="${file##*/}"
			title=

			"$YAML_TO_JSON" "$inPath" \
			| "$JSON_TO_MD" \
			| pandoc -f markdown -t html -s -c "$cssDir"/"$CSS_FILENAME" -F mermaid-filter --metadata title="$title" \
			> "$outPath"

			echo -n $'\a'
		;;
		*)
			outPath="$outDir/$file"
			# TODO なぜか機能しない
			# if [ ! "$inPath" -nt "$outPath" ]; then echo skip; continue; fi

			cp -p "$inPath" "$outPath"
		;;
	esac
}

transform "$SRC_DIR" "$DEST_DIR" yamlToHtmlCallback
