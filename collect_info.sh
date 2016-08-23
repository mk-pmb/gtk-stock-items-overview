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

  mkdir -p "$SELFPATH"/tmp || return $?
  cd "$SELFPATH"/tmp || return $?

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

  mkdir -p "$SELFPATH"/results || return $?
  cd "$SELFPATH"/results || return $?

  local RESULT_BFN='gtk-stock-items'

  nodejs ../combine_jsons.js >"$RESULT_BFN".json || return $?
  sed -re '1s~^~\xEF\xBB\xBFdefine(~;$s~$~);~
    ' -- "$RESULT_BFN".json >"$RESULT_BFN".amd.js || return $?

  COMBO_JSON=./results/"$RESULT_BFN".json nodejs ../tabulate.js \
    >"$RESULT_BFN".md || return $?
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
  local SEP='{ '
  local GX_SHOT_FN=
  local GX_TIMEOUT=
  local SCROT_PID=
  local SCROT_TMP=  # 'scrot.tmp.png'
      # ^-- no need; .iconfile_gxmsg === .iconfile_pygtk for all stock items
  local ICON_PYGTK=
  local ICON_GXMSG=

  local NUM=0
  for STOCK_ID in "${STOCK_IDS[@]}"; do
    let NUM="$NUM+1"
    ICON_PYGTK="$(guess_icon_strace python -c "${RENDER_PY//%/$STOCK_ID}")"
    printf '%s"%s": { "iconfile_pygtk": %s' "$SEP" "$STOCK_ID" \
      "${ICON_PYGTK:-null}"

    if [ -n "$SCROT_TMP" ]; then
      GX_SHOT_FN="gxmsg.${STOCK_ID,,}.png"
      if [ -f "$GX_SHOT_FN" ]; then
        SCROT_PID=
        GX_TIMEOUT=1
      else
        GX_TIMEOUT=2
        scrot --delay 1 --focused --silent "$SCROT_TMP" &
        SCROT_PID=$!
      fi
      ICON_GXMSG="GTK_STOCK_$STOCK_ID:0, :0,$NUM / ${#STOCK_IDS[@]}:0"
      ICON_GXMSG="$(guess_icon_strace gxmessage "$STOCK_ID" -nofocus -ontop \
        -timeout "$GX_TIMEOUT" -buttons "$ICON_GXMSG")"
      if [ -n "$SCROT_PID" ]; then
        wait "$SCROT_PID"
      fi
      if [ "$ICON_GXMSG" == "$ICON_PYGTK" ]; then
        echo -n ', "iconfile_gxmsg": true'
      else
        mv -- "$SCROT_TMP" "$GX_SHOT_FN"
        printf ',\n% 38s"icon_gxmsg": %s' '' "${ICON_GXMSG:-null}"
      fi
    fi

    echo -n ' }'
    # sleep 0.1s  # increase chance to have Ctrl-C terminate this loop
    SEP=$',\n  '
  done
  echo $'\n}'
}


function guess_icon_strace () {
  local TRACE="$(env LANG{,UAGE}=en_US.UTF-8 strace -o /dev/stdout "$@")"
  local ICON=
  local EXCLUDE='
    ("/usr/share/icons/DMZ-White/cursors/
    {st_mode=S_IFDIR|
    /apps/gxmessage.png",
    /icon-theme.cache",
    /index.theme",
    '
  EXCLUDE="${EXCLUDE//$'\n'    /$'\n'}"
  EXCLUDE="${EXCLUDE#$'\n'}"
  EXCLUDE="${EXCLUDE%$'\n'}"
  if <<<"$TRACE" grep -qPe '^write\(2,' -m 1; then
    sleep 2s    # error output from program => slow down the fail
  else
    ICON="$(<<<"$TRACE" grep -vFe "$EXCLUDE" \
      | grep -Fe 'lstat64("/usr/share/icons/' \
      | cut -d '"' -sf 2)"
    ICON="${ICON//$'\n'/\\n}"
  fi
  [ -n "$ICON" ] && printf '"%s"' "$ICON"
  return 0
}


function json_align () {
  sed -ure 's~\t~ ~g
    s~":~&                                               \t~
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
    s~^(\S+)\t[^\t]*<img src=("[^"<>]*")[^\t]*~  "\1": \{ "§": \2~
    s~\t(_rtl)\t[^\t]*<img src=("[^"<>]*").*$~, "§\1": \2~
    s~§~pygtk_docs_icon~g
    /^\s*"/s~$~ \},~p
    ' | sed -re '1s~^ ~\{~;$s~,$~\n}~' | json_align >pygtk-icons.json
}



















[ "$1" == --lib ] && return 0; collect_info "$@"; exit $?
