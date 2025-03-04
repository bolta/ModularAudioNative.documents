#!/bin/bash -eu

cd "$(dirname "$0")"

SRC_DIR=../contents
INTERM_DIR=../_interm
DEST_DIR=../target_doc

CARGO_DIR=..
YAML_TO_JSON="$CARGO_DIR/target/release/yaml_to_json"
JSON_TO_MD="../bin/to_md.jq"

# 文書置き場のルートにある想定
CSS_FILENAME=moddl.css

if [ $# -ge 1 ] && [ "$1" == '--local' ]; then
	LOCAL=1
else
	LOCAL=
fi

for cmd in cargo jq pandoc; do
	if ! which "$cmd" > /dev/null; then
		echo "This script requires \"$cmd\" available as a command." >&2
		exit 1
	fi
done

# YAML → JSON 変換ツールを作っておく
if [ ! -f "$YAML_TO_JSON" ]; then
	pushd "$CARGO_DIR" > /dev/null
		cargo build --release
	popd > /dev/null
fi

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
		# echo "$file"
		$callback "$inDir" "$file" "$outDir"
	done
}

function yamlToJsonCallback {
	local inDir="$1"
	local file="$2"
	local outDir="$3"

	inPath="$inDir/$file"
	ext="${file##*.}"
	case "$ext" in
		yaml | yml)
			outPath="$outDir/${file%.*}.json"
			if [ ! "$inPath" -nt "$outPath" ]; then return; fi

			"$YAML_TO_JSON" "$inPath" > "$outPath"

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
transform "$SRC_DIR" "$INTERM_DIR" yamlToJsonCallback

titles=$(./collect_titles.sh "$INTERM_DIR")

JSON_ROOT="$(
	readlink -f $INTERM_DIR
)";

function jsonToHtmlCallback {
	local inDir="$1"
	local file="$2"
	local outDir="$3"

	inPath="$inDir/$file"
	ext="${file##*.}"
	case "$ext" in
		json)
			outPath="$outDir/${file%.*}.html"
			if [ ! "$inPath" -nt "$outPath" ]; then return; fi

			# CSS のある場所の相対パスをがんばって求める
			cssDir="$(
				dirname "$(echo ${inPath#$inDir/})" \
				| awk '$0 != "." { gsub(/[^\/]*/, "..") } 1'
			)"
			# TODO タイトルをつけないと警告が出るが、つけると h1 が 2 重になってしまう。どうしたものか
			# title="${file##*/}"
			title=

			# $titles が絶対パスに基づくので、$inPath も絶対パスにする
			"$JSON_TO_MD" "$(readlink -f "$inPath")" --argjson TITLES "$titles" --arg JSON_ROOT "$JSON_ROOT" \
			| pandoc -f markdown --mathml -t html -s -c "$cssDir"/"$CSS_FILENAME" --metadata title="$title" \
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
transform "$INTERM_DIR" "$DEST_DIR" jsonToHtmlCallback

if [ -n "$LOCAL" ] && [ -f "$DEST_DIR/$CSS_FILENAME" ]; then
	{
		echo
		echo 'body { background-color: #e0e0ff; }'
	} >> "$DEST_DIR/$CSS_FILENAME"
fi

# 目次が過不足ないことを検証
diff=$(diff <(
	# 目次にある全ての文書
	{
		grep -o 'a href="[^"]*"' "$DEST_DIR"/toc.html | sed 's/^a href="//; s/"$//'
		echo toc.html
	} | sort
) <(
	# 実在する全ての文書
	{
		pushd "$DEST_DIR" > /dev/null
			find . -name \*.html | sed 's|^\./||' | sort
		popd > /dev/null
	}
) || :) # diff の結果がエラー扱いされてスクリプトが終了してしまわないように

if [ "$diff" != "" ]; then
	echo '目次不整合：以下の文書のうち、'
	echo '* "<" が付与されたものは、目次に記載されているのに実在しません。'
	echo '* ">" が付与されたものは、存在するのに目次に記載されていません。'

	echo "$diff"
fi
