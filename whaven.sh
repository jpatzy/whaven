#!/usr/bin/env bash
# Download and set random wallpapers from Wallhaven.cc
# Usage: whaven.sh <keywords>
#
# Requires: curl; Recommended: jq 
# For now, interval must be set inside script

#set -x            # all executed commands are printed to the terminal
set -e             # instructs bash to immediately exit if any command [1] has a non-zero exit status
#set -u            # a reference to any variable you haven't previously defined is an error, causes program to exit
set -o pipefail    # prevents errors in a pipeline from being masked
IFS=$" "           #

### Command line arguments ###
keywords=                          # added because "set -u" caused exit; $keywords was not defined before usage
for arg in "$@"; do
  #keywords="$keywords""$arg"+     # original sh line
  keywords+=${arg}+                # bash line
done

### Setup file paths; backup function ###
wallpaper="$HOME/.bg"
wallpaper_backup="$HOME/.bg.old"
bak_wallpaper() {
  if [[ -f "$wallpaper" ]]; then
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

####################################################################################

# "-sS" hide progress bar but show errors
# --connect-timeout (maximum time that you allow curl's connection to take
# --max-time 10     (how long each retry will wait)
# --retry 5         (it will retry 5 times)
# --retry-delay 0   (make curl sleep this amount of tie before each retry 

# --retry-max-time  (total time before it's considered failed)
# To limit  a  single  request's  maximum  time, use -m, --max-time.
# Set this option to zero to not timeout retries.

get_images() { API_CURL=$(curl -sS --max-time 10 --retry 2 --retry-delay 3 --retry-max-time 20 "$API_URL"); }

###################################################################################

### Consider trimming $API_CURL right away to store as smaller string, might be quicker?
#API_CURL_TRIMMED="${API_CURL%%thumbs*}" # remove all after thumbs

get_images                                          # first run to determine if keywords get results

EXIT_CODE=$?                                        # exit status of the last executed command
if [[ "$EXIT_CODE" == "0" ]]; then                  # if curl exit successfully
  if [[ $API_CURL == *"path"* ]]; then              # and if results contain full path url
    if hash jq > /dev/null 2>&1 ; then              # then decide which function to define
      dl_wallpaper() {
        IMAGE_URL=$(echo "$API_CURL" | jq -r '[.data[] | .path] | .[0]')
        curl -sS --max-time 10 --retry 2 --retry-delay 3 --retry-max-time 20 "$IMAGE_URL" -o "$wallpaper"
      } 
    else
      dl_wallpaper() {
	      trim="${API_CURL##*path}"
	      echo "$trim" | cut -c 4-59 | xargs curl -sS --max-time 10 --retry 2 --retry-delay 3 --retry-max-time 20 -o "$wallpaper"
      }
    fi
  else
    echo "No Results!"                              # if $API_CURL does not return at least one full path url
    exit 0                                          # then there are no images results
  fi
else
  echo "Curl failed"
  exit 0                                            # if get_images EXIT_CODE is non-zero, then exit
fi

### Set wallpaper function; add utility of choice ###
if hash sway > /dev/null 2>&1 ; then
  set_wallpaper() { swaymsg output "*" bg "$wallpaper" fill; }
elif hash feh > /dev/null 2>&1 ; then
  set_wallpaper() { feh --bg-fill "$wallpaper"; }
elif hash gsettings > /dev/null 2>&1 ; then
  WHICH_MODE=$(gsettings get org.gnome.desktop.interface color-scheme)
  if [[ "$WHICH_MODE" == "'prefer-dark'" ]]; then
    set_wallpaper() {
      gsettings reset org.gnome.desktop.background picture-uri-dark && \
      gsettings set org.gnome.desktop.background picture-uri-dark "$wallpaper"
    }
  elif [[ "$WHICH_MODE" == "'default'" ]]; then
    set_wallpaper() {
      gsettings reset org.gnome.desktop.background picture-uri && \
      gsettings set org.gnome.desktop.background picture-uri "$wallpaper"
    }
  fi
else
  echo "No wallpaper utility was found!!!"
  exit
fi

### Backup, download, and set wallpaper; run timer if set ###
if [[ -n "$interval" ]]; then
  while : ;
  do
    bak_wallpaper && get_images && dl_wallpaper && set_wallpaper
    sleep "$interval"
  done
else
  bak_wallpaper && dl_wallpaper && set_wallpaper;
fi
