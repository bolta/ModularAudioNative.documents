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
	.
else
	(input_filename | dirname) + "/" + . | removeDots
end;


def text: .
	# 内部リンクを処理（コマンドライン引数で --argjson TITLES '{ "/abs/path/to/json": "title" }' が与えられている必要がある）
	| gsub("%link\\((?<path>[^)]*)\\)"; "[\($TITLES[.path | toAbsPath + ".json"])](\(.path).html)")
	;
	

# 入れ子にしてはいけない
def elem(name; attrs; content): open(name; attrs) + content + close(name);

def heading(level): [
	("#" * level) + " " + .,
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
	. | text
elif type == "array" then
	map(blocks)
else
	empty
end;

def tableRow: "|" + (map(" " + . + " |") | join(""));

# パラメータ（params 配列の要素）を渡す
def requirement: 
	(if .required and (has("default") | not) then
		"**必須**"
	elif (.required | not) and has("default") then
		.default | if has("value") and has("behavior") | not then
			"デフォルト値 " + (.value | tostring)
		elif has("behavior") and has("value") | not then
			.behavior
		else
			"???????!!!"
		end
	else
		"????????"
	end);

# TODO table で書き直す
def params:
	(["名前", "必須/省略時", "説明"] | tableRow),
	(["----", "----", "----"] | tableRow),
	map(
		([
			.name,
			requirement,
			# TODO この手のテキスト処理は全てのテキストにかける
			.desc // "" | sub("\n+$"; "") | gsub("\n"; "<br>")
		] | tableRow)
	);

def events:
	map("* " + . + "\n");

def table:
	# テーブルの生成を blocks から切り出したいが、テーブル生成中に blocks へ再帰しているのでうまくいかない
	# （jq では相互再帰を書けないよう？）
	# そこでテーブルの生成処理は blocks の中に置き、そこで処理させるために table キーをつけて渡すようにする
	{ table: . } | blocks;

def directiveParams:
	{
		head: ["名前", "型", "必須/省略時", "説明"],
		body: map([.name, .type, requirement, .desc])
	} | table;


def transformNodeFactory: (
	(elem("span"; { class: "title-type" }; "node factory ") + .name | heading(1)),
	(.desc),
	("入力" | heading(2)),
	(.input | if . | trim == "%noInput" then "入力はありません。\n" else . end | blocks),
	("パラメータ" | heading(2)),
	(.params | params),
	("イベント" | heading(2)),
	(.events | events),
	("出力" | heading(2)),
	(.output | (
		(.desc | blocks),
		(.range | if . then ("範囲" | heading(3)), blocks else empty end)
	)),
	("詳細" | heading(2)),
	(.details | blocks),
	""
);

def transformDirective: (
	(elem("span"; { class: "title-type" }; "directive ") + .name | heading(1)),
	(.desc),
	("パラメータ" | heading(2)),
	(.params | directiveParams),
	("詳細" | heading(2)),
	(.details | blocks),
	""
);

def transformArticle: (
	(.title | heading(1)),
	(.content | blocks),
	""
);

if .nodeFactory then
	.nodeFactory | transformNodeFactory
elif .directive then
	.directive | transformDirective
elif .article then
	.article | transformArticle
else
	error("unknown document format: " + keys[0])
end
| [.] | flatten | join("\n")

