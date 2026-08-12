#!/usr/bin/env bash

# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 Nitrux Latinoamericana S.C. <hello@nxos.org>

set -Eeuo pipefail

repository_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "${repository_dir}"

# Install Build-Depends and remove the temporary dependency package afterward.
mk-build-deps -i -t "apt-get --yes" -r

# Generate the GTK 3 assets and compile the GTK 3 and GTK 4 stylesheets.
for source_dir in src/nitrux*; do
	name="${source_dir##*/}"
	theme_dir="themes/${name}"
	image_dir="${theme_dir}/gtk-3.0/img"
	gtk4_dir="${theme_dir}/gtk-4.0"

	mkdir -p -- "${image_dir}" "${gtk4_dir}"

	while IFS= read -r asset_id; do
		[[ -z "${asset_id}" ]] && continue

		inkscape "${source_dir}/img.svg" \
			--export-id="${asset_id}" \
			--export-id-only \
			--export-filename="${image_dir}/${asset_id}.png"
		inkscape "${source_dir}/img.svg" \
			--export-id="${asset_id}" \
			--export-id-only \
			--export-dpi=192 \
			--export-filename="${image_dir}/${asset_id}@2.png"
	done < "${source_dir}/index"

	sassc -t compressed "${source_dir}/scss/gtk.scss" "${theme_dir}/gtk-3.0/gtk.css"
	sassc -t compressed "${source_dir}/scss/gtk4.scss" "${theme_dir}/gtk-4.0/gtk.css"

	cp -a -- "${theme_dir}/gtk-4.0/gtk.css" "${theme_dir}/gtk-4.0/gtk-dark.css"

	cp -a -- "${source_dir}/gtk-2.0" "${theme_dir}/"
	cp -a -- "${source_dir}/index.theme" "${theme_dir}/"
done

debuild -b -uc -us

# debuild writes binary packages one directory above the repository.
shopt -s nullglob
packages=(../nitrux-gtk-theme_*.deb)
if (( ${#packages[@]} == 0 )); then
	echo "No Debian package was produced by debuild." >&2
	exit 1
fi
mv -- "${packages[@]}" .
