#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_DIR="$ROOT_DIR/images/equipment/fallback"
WEB_ICON_DIR="$ROOT_DIR/web/images/equipment/fallback"

if ! command -v magick >/dev/null 2>&1; then
	echo "[equipment-images] ImageMagick (magick) is required" >&2
	exit 1
fi

slot_icon_name()
{
	case "$1" in
		double_main_weapon|single_main_weapon|single_other_weapon|armor_head|+armor_cloth|armor_waste|armor_hand|armor_thou|armor_shoes|jewelry_ring|+jewelry_neck|jewelry_bangle|decorate_manteau|decorate_thing|decorate_tool)
			echo "$1"
			;;
		*)
			echo "decorate_tool"
			;;
	esac
}

mkdir -p "$WEB_ICON_DIR"
generated=0
synced=0
missing_source=0

for kind in weapon armor jewelry decorate; do
	for equipment_dir in "$ROOT_DIR/gamelib/clone/item/$kind"/*; do
		[[ -d "$equipment_dir" ]] || continue
		base_name="${equipment_dir##*/}"
		base_file="$equipment_dir/$base_name"
		[[ -f "$base_file" ]] || continue
		picture="$(sed -n 's/^[[:space:]]*picture[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$base_file" | head -n 1)"
		[[ -n "$picture" ]] || picture="$base_name"
		slot="$(sed -n 's/.*set_item_kind[[:space:]]*("[[:space:]]*\([^"]*\)"[[:space:]]*).*/\1/p' "$base_file" | head -n 1)"
		icon_name="$(slot_icon_name "$slot")"
		if [[ "$kind" == "weapon" && "$slot" == "single_main_weapon" ]]; then
			case "$base_name" in
				*fazhang*|*changzhang*|*zhang*) icon_name="magic_staff" ;;
				*bishou*) icon_name="single_other_weapon" ;;
			esac
		fi
		source_icon="$ICON_DIR/$icon_name.png"
		if [[ ! -f "$source_icon" ]]; then
			echo "[equipment-images] missing fallback source: $source_icon" >&2
			missing_source=$((missing_source + 1))
			continue
		fi
		output="$ROOT_DIR/images/$picture.gif"
		web_output="$ROOT_DIR/web/images/$picture.gif"
		if [[ ! -f "$output" ]]; then
			mkdir -p "$(dirname "$output")"
			checksum="$(cksum <<<"$base_name")"
			checksum="${checksum%% *}"
			hue=$((80 + checksum % 41))
			magick "$source_icon" \
				-modulate "100,108,$hue" \
				-resize 120x120 \
				-gravity center -background none -extent 128x128 \
				"$output"
			generated=$((generated + 1))
		fi
		if [[ ! -f "$web_output" ]]; then
			mkdir -p "$(dirname "$web_output")"
			cp "$output" "$web_output"
			synced=$((synced + 1))
		fi
	done
done

if (( missing_source > 0 )); then
	echo "[equipment-images] failed: missing_source=$missing_source" >&2
	exit 1
fi

echo "[equipment-images] generated=$generated web_synced=$synced"
