# Wallhaven Wallpaper Reborn

Port of wallhaven wallpaper plugin by [subpop](https://github.com/subpop/wallhaven-wallpaper-plasma) for plasma 6.

![screenshot.png](screenshot.png)

## Features

### original features

- automatically change wallpaper at a set interval.
- Search for wallpapers by keyword.
- Filter by categories.
- Filter by Purity.
- Sort by Relevance, Random, Date Added, Views, Favorites, Toplist.
- Set wallpaper to fill, fit, stretch, center, tile, or scale.
- Use own API key (only required for accessing NSFW wallpapers).

### New features

- Ported to plasma 6.
- add right click context menu action to open wallpaper in browser.
- add right click context menu action to fetch new wallpaper.
- streamline the settings page.
- allow using multiple tags as query parameters.
  - tags should be separated by commas.
  - one tag is chosen randomly from the list of tags for each wallpaper.
- add tooltip button to show how to search for wallpapers.
- automatically refresh the wallpaper after changing settings.
- show notification when fetching new wallpaper or when an error occurs.

### How to Search

the query field supports all types of queries supported by the wallhaven API, this means other than tags, you can also filter by:

- wallhaven user name: `@username`
- wallpapers similar to a wallpaper: `id:123456`
- you can combine the above with tags: `@username,tag1,tag2,id:123456` this will find a wallpaper matching any of the tags, the user, or the id each time you fetch a new wallpaper.

for more information about the wallhaven API, you can check the [official documentation](https://wallhaven.cc/help/api).

### Current issues

- the plugin cannot be set as lock screen wallpaper. ([networking related](https://bugs.kde.org/show_bug.cgi?id=483094))
- system settings crashes after setting the plugin as wallpaper and clicking apply.
- current wallpaper is not shown in the plugin settings page the first time the plugin is set as wallpaper.

## Installation

### KDE Store

Install the plugin from the KDE Store Plasma 6 version

- Right click on the Desktop > Configure Desktop and Wallpaper... > Get New Plugins
- Search for "Wallhaven Wallpaper Reborn", install and set it as your wallpaper.
- To set as Lock Screen wallpaper go to System settings > Screen Locking > Appearance: Configure...


### From source

installation requires `kpackagetool6` which can be found on the `kpackage` package on arch based distros, `kpackagetool6` on Suse based distros, and `kf6-kpackage` on debian based distros.

```bash
git clone https://github.com/Blacksuan19/plasma-wallpaper-wallhaven-reborn.git
cd plasma-wallpaper-wallhaven-reborn
kpackagetool6 --type Plasma/Wallpaper --install package/
```

additional setup might be required to get the plugin to work, as below:

- set the plugin as your wallpaper in the wallpaper settings.
- close the settings window.
- open the settings window again, new wallpaper should be fetched.

if after the above steps the wallpaper is still not fetched or applied, you can try the following:

- restart plasmashell with `killall plasmashell && kstart5 plasmashell`.
- refresh the wallpaper from context menu or settings page.
