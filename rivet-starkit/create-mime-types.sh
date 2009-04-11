#! /bin/bash

cat /etc/httpd/mime.types | \
	sed 's@#.*$@@' | \
	while read mt exts; do
		if [ -z "${exts}" ]; then
			continue
	fi
	cb=""

	for ext in $exts; do
		cb="${cb} \"*.${ext}\" - "
	done
	cb="${cb} { set statictype \"$mt\" }"
	echo $cb
done | \
	grep -v 'application/octet-stream' | \
	sed "s@^@$(echo -e "\t\t")@"
