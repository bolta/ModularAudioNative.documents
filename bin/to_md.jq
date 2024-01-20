#!/usr/bin/jq -rf

def open(name; attrs): "<" + name
	+ (attrs as $attrs | $attrs | keys | map(" " + . + "=\"" + ($attrs[.] | @html) + "\"") | join(""))
	+ ">"
	;
def close(name): "</" + name + ">";

def trim: sub("^\\s+"; "") | sub("\\s+$"; "");

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
	else
		"?"
	end
elif type == "string" then
	.
elif type == "array" then
	map(blocks)
else
	empty
end;

def tableRow: "|" + (map(" " + . + " |") | join(""));

def params:
	(["名前", "必須/省略時", "説明"] | tableRow),
	(["----", "----", "----"] | tableRow),
	map(
		([
			.name,
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
			end),
			# TODO この手のテキスト処理は全てのテキストにかける
			.desc // "" | sub("\n+$"; "") | gsub("\n"; "<br>")
		] | tableRow)
	);

def events:
	map("* " + . + "\n");

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

.nodeFactory | transformNodeFactory | [.] | flatten | join("\n")
