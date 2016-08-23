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

  mkdir -p cache || return $?
  cd cache || return $?

  local SCAN_LANGS=(
    de_DE
    en_US
    )
  local SCAN_LANG=
  for SCAN_LANG in "${SCAN_LANGS[@]}"; do
    LANGUAGE="$SCAN_LANG" ../find_labels.py >labels."${SCAN_LANG,,}".json
  done

  download gnome_dev_man.html \
    'https://developer.gnome.org/gtk3/stable/gtk3-Stock-Items.html' || return $?
  download pygtk-stock.html \
    'http://pygtk.org/docs/pygtk/gtk-stock-items.html'

  collect_item_names | sort -u >item_names.txt
  local STOCK_IDS=()
  readarray -t STOCK_IDS <item_names.txt

  [ ! -f icon_files.json ] && collect_icon_filenames \
    | tee icon_files.json.tmp && mv -v icon_files.json{.tmp,}

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


function collect_item_names () {
  cut -d '"' -sf 2 labels.*.json | sed -re '
    s!^gtk-!!;s!-!_!g;s![a-z]+!\U&!g'
  sed -nre 's~^<td class="function_name"><a [^<>]+>GTK_STOCK_([^<>]+|\
    )</a>.*$~\1~p' gnome_dev_man.html
  grep -oPe '<code class="literal">gtk.STOCK_[^<>]+</code>' \
    pygtk-stock.html | cut -d '<' -sf 2 | cut -d _ -sf 2-
}


function collect_icon_filenames () {
  local RENDER_PY='import gtk; '
  RENDER_PY+='gtk.Label().render_icon(gtk.STOCK_%, gtk.ICON_SIZE_BUTTON)'

  local STOCK_ID=
  local ICON=
  local SEP='{ '

  for STOCK_ID in "${STOCK_IDS[@]}"; do
    printf '%s"%s": { "iconFile": ' "$SEP" "$STOCK_ID"
    ICON="$(strace -o /dev/stdout python -c "${RENDER_PY//%/$STOCK_ID}")"
    if <<<"$ICON" grep -qPe '^write\(2,' -m 1; then
      sleep 2s    # Python errors => slow down the fail
      ICON=
    else
      ICON="$(<<<"$ICON" grep -Fe 'lstat64("/usr/share/icons/' \
        | cut -d '"' -sf 2)"
      ICON="${ICON//$'\n'/\\n}"
    fi
    if [ -n "$ICON" ]; then
      printf '"%s"' "$ICON"
    else
      echo -n null
    fi
    echo -n ' }'
    # sleep 0.1s  # increase chance to have Ctrl-C terminate this loop
    SEP=$',\n  '
  done
  echo $'\n}'
}
















[ "$1" == --lib ] && return 0; collect_info "$@"; exit $?
