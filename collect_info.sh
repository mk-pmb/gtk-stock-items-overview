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
    LANGUAGE="$SCAN_LANG" ../find_labels.py \
      | json_align >labels."${SCAN_LANG,,}".json
  done

  read_gnome_dev_docs || return $?
  read_pygtk_docs || return $?

  collect_item_names | sort -u >item_names.txt
  local STOCK_IDS=()
  readarray -t STOCK_IDS <item_names.txt

  [ ! -f icon_files.json ] && collect_icon_filenames | json_align \
    | tee icon_files.json.tmp && mv -v icon_files.json{.tmp,}

  nodejs ../combine_jsons.js >combined.json || return $?
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


function json_align () {
  sed -ure 's~\t~ ~g
    s~:~&                                               \t~
    s~^([^\t]{35}) *\t~\1~
    s~ +\t~~g'
}


function read_gnome_dev_docs () {
  download gnome_dev_man.html \
    'https://developer.gnome.org/gtk3/stable/gtk3-Stock-Items.html' || return $?
  sed -nure 's~^\s*<pre\b[^<>]*>#define GTK_STOCK_(\S+)\s.*$|$\
      ~  "\1": { "gnome_dev_defined": true },~p
    ' -- gnome_dev_man.html | sed -re '1s~^ ~\{~;$s~,$~\n}~
    ' | json_align >gnome_dev_mentions.json
  sed -nure 's~^.*>GTK_STOCK_([^<> ]+)[ <].*\b(deprecated) since version ($\
    |[0-9.]+) .*$~  "\1": { "gnome_dev_\2": "\3" },~p
    ' -- gnome_dev_man.html | sed -re '1s~^ ~\{~;$s~,$~\n}~
    ' | json_align >gnome_dev_deprecated.json
  <gnome_dev_man.html tr -s '\r\n\t ' ' ' | sed -re 's~<hr|$~\n~g' | sed -nre '
    s~^.*>#define GTK_STOCK_(\S+)\s.*<p class="since">Since: ([0-9.]+|$\
      ).*$~  "\1": { "gnome_dev_since": "\2" },~p
    ' | sed -re '1s~^ ~\{~;$s~,$~\n}~' | json_align >gnome_dev_since.json
}


function read_pygtk_docs () {
  download pygtk-stock.html \
    'http://pygtk.org/docs/pygtk/gtk-stock-items.html' || return $?
  <pygtk-stock.html tr -s '\r\n\t ' ' ' | sed -re 's~</?tr>|$~\n~g' | sed -re '
    s~^.*>gtk\.STOCK_([^<> ]+)</code>~\1\t~
    s~^(\S+)(\t.*)> (RTL) version is ~\1\2\t_\L\3\E\t~
    s~</?(span|p|td|tr)\b[^<>]*>~~g
    /\t/!d' | sed -nre '
    s~^(\S+)\t[^\t]*<img src=("[^"<>]*")[^\t]*~  "\1": \{ "pygtk_icon": \2~
    s~\t(_rtl)\t[^\t]*<img src=("[^"<>]*").*$~, "pygtk_icon\1": \2~
    /^\s*"/s~$~ \},~p
    ' | sed -re '1s~^ ~\{~;$s~,$~\n}~' | json_align >pygtk-icons.json
}



















[ "$1" == --lib ] && return 0; collect_info "$@"; exit $?
