# Wallhaven Wallpaper Reborn

Port of wallhaven wallpaper plugin by [subpop](https://github.com/subpop/wallhaven-wallpaper-plasma) for plasma 6.

## Features

### original features

- automatically change wallpaper at a set interval
- Search for wallpapers by keyword
- Filter by categories
- Filter by Purity
- Sort by Relevance, Random, Date Added, Views, Favorites, Toplist
- Set wallpaper to fill, fit, stretch, center, tile, or scale
- Use own API key (only required for accessing NSFW wallpapers)

### New features

- Ported to plasma 6
- add right click context menu action to open wallpaper in browser

## Current status

All features work as they did in the original plugin. that also includes the same bugs:

- you need to manually refresh the wallpaper after changing the settings
- after installation, you need to restart plasmashell for the plugin to work properly.

## Installation

installation requires `kpackagetool6` which can be found on the `kpackage` package on arch based distros, `kpackagetool6` on Suse based distros, and `kf6-kpackage` on debian based distros.

```bash
git clone https://github.com/Blacksuan19/plasma-wallpaper-wallhaven-reborn.git
cd plasma-wallpaper-wallhaven-reborn
kpackagetool6 --type Plasma/Wallpaper --install package/
```

- set the plugin as your wallpaper in the wallpaper settings
- restart plasmashell
- refresh the wallpaper

![screenshot.png](screenshot.png)
