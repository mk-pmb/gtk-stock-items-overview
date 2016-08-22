#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
SELFPATH="$(readlink -m "$BASH_SOURCE"/..)"


function collect_info () {
  cd "$SELFPATH" || return $?
  local RUNMODE="$1"; shift
  case "$RUNMODE" in
    '' ) ;;
    :* ) "${RUNMODE#:}" "$@"; return $?;;
    * ) echo "E: unsupported runmode: $RUNMODE" >&2; return 2;;
  esac

  local SCAN_LANGS=(
    de_DE
    en_US
    )
  local SCAN_LANG=
  for SCAN_LANG in "${SCAN_LANGS[@]}"; do
    LANGUAGE="$SCAN_LANG" ./find_labels.py >cache/labels."$SCAN_LANG".json
  done

  download cache/gnome_dev_man.html \
    'https://developer.gnome.org/gtk3/stable/gtk3-Stock-Items.html' || return $?
  download cache/pygtk-stock.html \
    'http://pygtk.org/docs/pygtk/gtk-stock-items.html'

  collect_item_names | sort -u >cache/item_names.txt

  # stockid_to_icon_filename | json-str-quote

  return 0
}


function download () {
  local DEST_FN="$1"; shift
  local SRC_URL="$1"; shift
  [ -f "$DEST_FN" ] && [ -s "$DEST_FN" ] && return 0
  wget -O "$DEST_FN".tmp "$SRC_URL" || return $?
  mv -v -- "$DEST_FN"{.tmp,} || return $?
  return 0
}


function stockid_to_icon_filename () {
  local ST_ID="$1"
  local RENDER_PY="import gtk; "
  RENDER_PY+="gtk.Label().render_icon(gtk.STOCK_${ST_ID}, "
  RENDER_PY+="gtk.ICON_SIZE_MEDIUM_TOOLBAR)"
  strace python -c "$RENDER_PY" 2>&1 \
    | grep -Fe 'lstat64("/usr/share/icons/' | cut -d '"' -sf 2
}


function collect_item_names () {
  cut -d '"' -sf 2 cache/labels.*.json | sed -re '
    s!^gtk-!!;s!-!_!g;s![a-z]+!\U&!g'
  sed -nre 's~^<td class="function_name"><a [^<>]+>GTK_STOCK_([^<>]+|\
    )</a>.*$~\1~p' cache/gnome_dev_man.html
  grep -oPe '<code class="literal">gtk.STOCK_[^<>]+</code>' \
    cache/pygtk-stock.html | cut -d '<' -sf 2 | cut -d _ -sf 2-
}
















[ "$1" == --lib ] && return 0; collect_info "$@"; exit $?
