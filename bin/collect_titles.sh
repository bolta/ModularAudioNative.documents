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
					# "table of contents: " + .toc.title
					.toc.title
				elif has("nodeFactory") then
					# "node factory: " + .nodeFactory.name
					.nodeFactory.name
				elif has("constant") then
					# "constant: " + .constant.name
					.constant.name
				elif has("function") then
					# "function: " + .function.name
					.function.name
				elif has("construction") then
					# "construction: " + .construction.name
					.construction.name
				elif has("article") then
					.article.title
				elif has("mmlCommand") then
					# "MML command: " + .mmlCommand.name
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


