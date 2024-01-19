#!/usr/bin/jq -rf

def open(name; attrs): "<" + name
	+ (attrs as $attrs | $attrs | keys | map(" " + . + "=\"" + ($attrs[.] | @html) + "\"") | join(""))
	+ ">"
	;
def close(name): "</" + name + ">";

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
			"```",
			(.code | blocks),
			["```"],
			(.desc | blocks),
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
	"*"
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


def transformNodeFactory: (
	(.name | heading(1)),
	(.desc),
	("入力" | heading(2)),
	(.input),
	("パラメータ" | heading(2)),
	(.params | params),
	("イベント" | heading(2)),
	("blah blah\n" | blocks), # 改行で終わってない場合に構造が崩れるので改行を補う必要がある
	("出力" | heading(2)),
	(.output.desc | blocks),
	("詳細" | heading(2)),
	(.details | blocks),
	""
);

.nodeFactory | transformNodeFactory | [.] | flatten | join("\n")
