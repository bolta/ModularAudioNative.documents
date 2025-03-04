#!/usr/bin/jq -rf

def open(name; attrs): "<" + name
	+ (attrs as $attrs | $attrs | keys | map(" " + . + "=\"" + ($attrs[.] | @html) + "\"") | join(""))
	+ ">"
	;
def close(name): "</" + name + ">";

def trim: sub("^\\s+"; "") | sub("\\s+$"; "");

# foo/bar/baz/../../qux なども扱えるよう再帰で処理
def removeDots_: if test("[^/]+/\\.\\./") then
	gsub("[^/]+/\\.\\./"; "") | removeDots_
else
	.
end;
def removeDots: gsub("/(\\./)+"; "/") | removeDots_;

def dirname: sub("/+$"; "") | sub("/+[^/]+$"; "");
def toAbsPath: if startswith("/") then
	($JSON_ROOT | gsub("/?$"; "")) + .
else
	(input_filename | dirname) + "/" + . | removeDots
end;
def toRelPath: if startswith("/") then
	# ドキュメントルートからのパスを、現在文書からのパスに変換
	. as $path
	| input_filename | sub("[^/]*$"; "") as $absCurDir
	| $absCurDir[($JSON_ROOT | gsub("/?$"; "/")) | length :] as $relCurDirFromJsonRoot
	| $relCurDirFromJsonRoot | gsub("[^/]+/"; "../") | sub("/$"; "") + $path
else
	.
end;


def text: .
	# 内部リンクを処理（コマンドライン引数で --argjson TITLES '{ "/abs/path/to/json": "title" }' が与えられている必要がある）
	| gsub("%constr(?:uction)?\\((?<name>[^)]*)\\)"; "%linkCode(/reference/moddl/constructions/\(.name))")
	| gsub("%func(?:tion)?\\((?<name>[^)]*)\\)"; "%linkCode(/reference/moddl/builtin_library/functions/\(.name))")
	| gsub("%oper(?:ator)?\\((?<name>[^)]*)\\)"; "%linkCode(/reference/moddl/operators/\(.name))")
	| gsub("%const(?:ant)?\\((?<name>[^)]*)\\)"; "%linkCode(/reference/moddl/builtin_library/constants/\(.name))")
	| gsub("%node[Dd]ef\\((?<name>[^)]*)\\)"; "%linkCode(/reference/moddl/builtin_library/node_defs/\(.name))")
	| gsub("%mml[Cc](?:md|ommand)\\((?<name>[^)]*)\\)"; "%linkCode(/reference/mml/commands/\(.name))")
	# TODO リンク文言に半角閉じ括弧を使いたい場合は対応できない
	| gsub("%link\\((?<path>[^,)]*)(?:,\\s*(?<text>[^)]+))?\\)"; "[\(if .text then .text | stderr else $TITLES[.path | toAbsPath + ".json"].title end)](\(.path | toRelPath).html)")
	| gsub("%linkCode\\((?<path>[^,)]*)(?:,\\s*(?<text>[^)]+))?\\)"; "[`\(if .text then .text | stderr else $TITLES[.path | toAbsPath + ".json"].title | gsub("\\\\"; "") end)`](\(.path | toRelPath).html)")
	;
	

# 入れ子にしてはいけない
def elem(name; attrs; content): open(name; attrs) + content + close(name);

def heading(level): [
	("#" * level) + " " + (. | text),
	""
];

def paragraph: [
	(. | text),
	""
];

def blocks: if type == "object" then
	if has("caution") then
		.caution | (
			open("div"; { class: "caution" }),
			blocks,
			close("div")
		)
	elif has("tips") then
		.tips | (
			open("div"; { class: "tips" }),
			blocks,
			close("div")
		)
	elif has("note") then
		.note | (
			open("div"; { class: "note" }),
			blocks,
			close("div")
		)
	elif has("sample") then
		.sample | (
			open("div"; { class: "sample" }),
			open("div"; { class: "code" }),
			"```",
			(.code | blocks),
			["```"],
			close("div"),
			open("div"; { class: "desc" }),
			(.desc | blocks),
			close("div"),
			close("div")
		)
	elif has("table") then
		.table | (
			open("table"; { }),
			if has("head") then
				open("tr"; { }),
				(.head | map(
					open("th"; { }),
					blocks,
					close("th")
				)[]),
				close("tr")
			else empty end,
			if has("body") then
				(.body | map(
					open("tr"; { }),
					map(
						open("td"; { }),
						blocks,
						close("td")
					)[],
					close("tr")
				)[])
			else empty end,
			close("table")
		)
	else
		"?"
	end
elif type == "string" then
	(. + "\n") | text
elif type == "number" then
	(. | tostring + "\n") | text
elif type == "array" then
	map(blocks)
else
	empty
end;

def table:
	# テーブルの生成を blocks から切り出したいが、テーブル生成中に blocks へ再帰しているのでうまくいかない
	# （jq では相互再帰を書けないよう？）
	# そこでテーブルの生成処理は blocks の中に置き、そこで処理させるために table キーをつけて渡すようにする
	{ table: . } | blocks;

def tableRow: "|" + (map(" " + . + " |") | join(""));

# パラメータ（params 配列の要素）を渡す
def requirement: 
	(if .required and (has("default") | not) then
		"**必須**"
	elif (.required | not) and has("default") then
		.default | if has("value") and (has("behavior") | not) then
			"`" + (.value | tostring) + "`"
		elif has("behavior") and (has("value") | not) then
			.behavior
		else
			"???????!!!"
		end
	else
		"????????"
	end);

# TODO table で書き直す
def nodeDefParams:
	if . then
		(["名前", "必須/省略時", "説明"] | tableRow),
		(["----", "----", "----"] | tableRow),
		map(
			([
				"`" + .name + "`",
				requirement,
				# TODO この手のテキスト処理は全てのテキストにかける
				.desc // "" | sub("\n+$"; "") | gsub("\n"; "<br>")
			] | tableRow)
		)
	else
		"入力はありません。" | paragraph
	end;

def functionParams:
	if . then
		{
			head: ["名前", "型", "必須/省略時", "説明"],
			body: map([.name, .type, requirement, .desc])
		} | table
	else
		"引数はありません。" | paragraph
	end;

def functionTypeParams:
	{
		head: ["名前", "型定義"],
		body: map([.name, .type])
	} | table;

def functionValue:
	{
		head: ["型", "説明"],
		body: [[.type, .desc]]
	} | table;

def events:
	if . then
		{
			head: ["種別", "キー", "説明"],
			body: map([.type, .key, .desc])
		} | table
	else
		"イベントを受け取りません。" | paragraph
	end;

def constructionParams:
	{
		head: ["名前", "型", "必須/省略時", "説明"],
		body: map([.name, .type, requirement, .desc])
	} | table;

def toLink: ("%link(" + . + ")") | text;

def transformTocItems(depth; baseDir): (
	open("ul"; { class: "toc" }),
	map(
		(if type == "object" then . else { item: . } end) as $entry
		| (baseDir + $entry.item) as $key # rel_dir/filename_without_ext
		| ($key | toAbsPath + ".json") as $fullPath # リンク先 json のフルパス
		| ($TITLES[$fullPath].toc) as $toc # リンク先が toc の場合、その内容

		| (
			open("li"; { }),
			if $toc then
				open("details"; { open: "open" }),
				open("summary"; { }),
				($key | toLink),
				close("summary"),
				# リンク先 toc の内容をここに展開する。
				# リンク先の items のキーを現在の $key のディレクトリで修飾してやる
				($toc.items | transformTocItems(depth + 1; $key | sub("/[^/]*$"; "/"))),
				close("details")
			elif $entry.section then
				($entry.section | text),
				($entry.items | transformTocItems(depth + 1; baseDir))
			else
				($key | toLink)
			end,
			close("li")
		)
	),
	close("ul")
);

def transformToc: (
	(.title | heading(1)),
	(.items | transformTocItems(0; "")),
	""
);

def transformNodeFactory: (
	(if .functionParams then "()" else "" end) as $paren
	| (elem("span"; { class: "title-type" }; "node def ") + .name + $paren | heading(1)),
	(.desc | blocks),
	if .functionTypeParams then
		("関数の型定義" | heading(2)),
		(.functionTypeParams | functionTypeParams)
	else
		empty
	end,
	if .functionParams then
		("関数の引数" | heading(2)),
		(.functionParams | functionParams)
	else
		empty
	end,
	("主入力" | heading(2)),
	(.input | if . | trim == "%noInput" then "入力はありません。\n" else . end | blocks),
	("パラメータ入力" | heading(2)),
	(.params | nodeDefParams),
	("イベント" | heading(2)),
	(.events | events),
	("出力" | heading(2)),
	(.output | (
		(.desc | blocks),
		(.range | if . then ("範囲" | heading(3)), blocks else empty end)
	)),
	if .examples then
		("使用例" | heading(2)),
		(.examples | blocks)
	else
		empty
	end,
	if .details then
		("詳細" | heading(2)),
		(.details | blocks)
	else
		empty
	end,
	""
);

def transformConstant: (
	# TODO constant true: Number = 1 のように 1 行にまとめた方が見やすいか
	(elem("span"; { class: "title-type" }; "constant ") + .name | heading(1)),
	(.desc | blocks),
	("型" | heading(2)),
	(.type | blocks),
	if .value then
		("値" | heading(2)),
		(.value | blocks)
	else
		empty
	end,
	if .details then
		("詳細" | heading(2)),
		(.details | blocks)
	else
		empty
	end,
	""
);

def transformFunction: (
	(if .operatorNotation then "operator" else "function" end) as $category
	| (elem("span"; { class: "title-type" }; $category + " ") + .name | heading(1)),
	(.desc | blocks),
	if .operatorNotation then
		("記法" | heading(2)),
		(.operatorNotation | blocks)
	else
		empty
	end,
	if .typeParams then
		("型定義" | heading(2)),
		(.typeParams | functionTypeParams)
	else
		empty
	end,
	("引数" | heading(2)),
	(.params | functionParams),
	if .constraints then
		("制約" | heading(2)),
		(.constraints | blocks)
	else
		empty
	end,
	("値" | heading(2)),
	(.value | functionValue),
	if .examples then
		("使用例" | heading(2)),
		(.examples | blocks)
	else
		empty
	end,
	if .details then
		("詳細" | heading(2)),
		(.details | blocks)
	else
		empty
	end,
	""
);

def transformConstruction: (
	(elem("span"; { class: "title-type" }; "construction ") + .name | heading(1)),
	(.desc | blocks),
	("パラメータ" | heading(2)),
	(.params | constructionParams),
	("詳細" | heading(2)),
	(.details | blocks),
	""
);

def transformArticle: (
	(.title | heading(1)),
	(.content | blocks),
	""
);

def mmlCommandParams:
	{
		head: ["名前", "型", "必須/省略時", "説明"],
		body: map([.name, .type, requirement, .desc])
	} | table;

def transformMmlCommand: (
	(elem("span"; { class: "title-type" }; "MML command ") + .name | heading(1)),
	(.desc | blocks),
	("書式" | heading(2)),
	(.format | blocks),
	if .params then
		("パラメータ" | heading(2)),
		(.params | mmlCommandParams)
	else
		empty
	end,
	("詳細" | heading(2)),
	(.details | blocks),
	""
);

if .toc then
	.toc | transformToc
elif .nodeFactory then # TODO nodeDef に変える
	.nodeFactory | transformNodeFactory
elif .constant then
	.constant | transformConstant
elif .function then
	.function | transformFunction
elif .construction then
	.construction | transformConstruction
elif .article then
	.article | transformArticle
elif .mmlCommand then
	.mmlCommand | transformMmlCommand
else
	error("unknown document format: " + keys[0])
end
| [.] | flatten | join("\n")

