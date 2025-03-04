#!/bin/sh -eu

BASE_DIR="$1"
cd "$BASE_DIR"

find -name \*.json \
| while read path; do readlink -f "$path"; done \
| xargs jq '
	{
		(input_filename | sub("^\\./"; "")): ({
			title: (
				if has("toc") then
					.toc.title
				elif has("dataType") then
					.dataType.name
				elif has("nodeFactory") then
					.nodeFactory.name
				elif has("constant") then
					.constant.name
				elif has("function") then
					.function.name
				elif has("construction") then
					.construction.name
				elif has("article") then
					.article.title
				elif has("mmlCommand") then
					.mmlCommand.name
				else
					"???"
				end
			),
		} + if has("toc") then
			.
		else
			{ }
		end)
	}
' | jq -s add


