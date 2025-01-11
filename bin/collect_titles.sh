#!/bin/sh -eu

BASE_DIR="$1"
cd "$BASE_DIR"

find -name \*.json \
| while read path; do readlink -f "$path"; done \
| xargs jq '
	{
		(input_filename | sub("^\\./"; "")): (if has("article") then
			.article.title
		elif has("nodeFactory") then
			"node factory: " + .nodeFactory.name
		elif has("directive") then
			"directive: " + .directive.name
		else
			"???"
		end)
	}
' | jq -s add
