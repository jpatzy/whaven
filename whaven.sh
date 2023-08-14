#!/usr/bin/env bash
# Download and set random wallpapers from Wallhaven.cc
# Usage: whaven.sh <keywords>
#
# Requires: curl; Recommended: jq 
# For now, interval must be set inside script

#set -x # all executed commands are printed to the terminal
#set -e # instructs bash to immediately exit if any command [1] has a non-zero exit status
#set -u # a reference to any variable you haven't previously defined is an error, causes program to exit
#set -o pipefail # prevents errors in a pipeline from being masked
IFS=$" "

### Command line arguments ###
keywords= # added because "set -u" caused exit; "keywords" was not defined before usage
for arg in "$@"; do
  #keywords="$keywords""$arg"+     # original sh line
  keywords+=${arg}+                # bash line
  #keywords+="$arg"+               # alternative?
done
#echo "$keywords" #### quality check

### Setup file paths; backup function ###
wallpaper="$HOME/.bg"
wallpaper_backup="$HOME/.bg.old"
bak_wallpaper() {
  if [ -f "$wallpaper" ]; then
    mv -f "$wallpaper" "$wallpaper_backup"
  fi
}

# ===== API options ===== # 
api="https://wallhaven.cc/api/v1/search?"   # base url
key=                                        # personal api key (only needed for NSFW wallpapers)
categories=111                              # 1=on,0=off (general/anime/people)
purity=100                                  # 1=on,0=off (sfw/sketchy/nsfw)
ratios=landscape                            # 16x9/16x10/4:3/landscape
sorting=random                              # date_added, relevance, random, views, favorites, toplist
interval=                                   # seconds between wallpaper transition
API_URL="${api}apikey=${key}&q=${keywords}&categories=${categories}&purity=${purity}&ratios=${ratios}&sorting=${sorting}"

### Set wallpaper function; add utility of choice ###
if command -v sway > /dev/null 2>&1 ; then
  set_wallpaper() { swaymsg output "*" bg "$wallpaper" fill; }
elif command -v feh > /dev/null 2>&1 ; then
  set_wallpaper() ( feh --bg-fill "$wallpaper"; )
elif command -v gsettings > /dev/null 2>&1 ; then
  WHICH_MODE=$(gsettings get org.gnome.desktop.interface color-scheme)
  if [ "$WHICH_MODE" = "'prefer-dark'" ]; then
    set_wallpaper() {
      gsettings reset org.gnome.desktop.background picture-uri-dark
      gsettings set org.gnome.desktop.background picture-uri-dark "$wallpaper"
    }
  elif [ "$WHICH_MODE" = "'default'" ]; then
    set_wallpaper() {
      gsettings reset org.gnome.desktop.background picture-uri
      gsettings set org.gnome.desktop.background picture-uri "$wallpaper"
    }
  fi
fi

####################################################################################
# "-sS" hide progress bar but show errors
# --connect-timeout (maximum time that you allow curl's connection to take
# --max-time 10     (how long each retry will wait)
# --retry 5         (it will retry 5 times)
# --retry-delay 0   make curl sleep this amount of tie before each retry 
# --retry-max-time  (total time before it's considered failed)

API_CURL=$(curl -s --connect-timeout 5 --retry 1 --retry-delay 3 "$API_URL")
#API_CURL=$(curl -s "$API_URL")
####################################################################################

# https://everything.curl.dev/usingcurl/returns
EXIT_CODE=$?                                        # exit status of the last executed command
if test "$EXIT_CODE" = "0"; then                    # if curl exit successfully
  if [[ ! $API_CURL == *"path"* ]]; then            # if no full image path returns, then exit
    echo "No Results!"
    exit
  fi
fi

# If curl does not exit successfully, maybe add loop to retry API_CURL
# For now I'm instead using curl options to retry once on failure

# ===== last working solution ===== #
### Run first curl; check if a full url path is returned ###
#API_CURL=$(curl -sS "$API_URL")
#case "$API_CURL" in
#  *path*) ;;
#  *) echo "No results!" && exit ;;
#esac

###################################################################################

### Download function; use jq if available ###
if command -v jq > /dev/null 2>&1 ; then
  dl_wallpaper() { echo "$API_CURL" | jq '[.data[] | .path] | .[0]' | xargs curl -s -o "$wallpaper"; }
else
  dl_wallpaper() { trim="${API_CURL##*path}"; echo "$trim" | cut -c 4-59 | xargs curl -s -o "$wallpaper"; }
fi

### Backup, download, and set wallpaper; run timer if set ###
if [ -n "$interval" ]; then
  while : ;
  do
    bak_wallpaper && API_CURL=$(curl -s "$API_URL") # get new image url each cycle
    dl_wallpaper && set_wallpaper
    sleep "$interval"
  done
else
  bak_wallpaper && dl_wallpaper && set_wallpaper;
fi
