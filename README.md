# Wallhaven Wallpaper Reborn

Port of wallhaven wallpaper plugin by
[subpop](https://github.com/subpop/wallhaven-wallpaper-plasma) for plasma 6.

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
  - tags must be real wallhaven tag names (e.g. `nature`, `landscape`).
  - tags should be separated by commas.
  - one tag is chosen randomly from the list of tags for each wallpaper.
- add ability to pass a custom aspect ratio or multiple aspect ratios.
- add ability to pass a custom resolution.
- add tooltip button to show how to search for wallpapers.
- automatically refresh the wallpaper after changing settings.
- show notification when fetching new wallpaper or when an error occurs.
- add UI to allow toggling notifications.
- retry fetching wallpaper when a network error occurs.
- follow system color scheme to automatically fetch darker wallpapers in Dark
  Mode.
- save wallpapers to a personal collection with offline support.
  - right-click context menu to save the current wallpaper (downloaded locally).
  - use saved wallpapers only mode to cycle through your collection offline.
  - choose between looping through saved wallpapers or fetching new ones when
    exhausted.
  - shuffle saved wallpapers for random playback or display in sequential order.
  - open the saved wallpapers folder from settings.
  - clear all removes both the list and the local files.
  - automatically fetch from Wallhaven when saved list is empty.

### How to Search

the query field accepts the following types of entries, each matching the
wallhaven API search syntax:

- **tag name** (fuzzy keyword search): `nature`, `landscape`, `anime` — must be
  real wallhaven tag names, not arbitrary words or numbers like `tag1` or
  `tag8621`.
- **exact tag by ID**: `id:1` — searches for wallpapers with the tag that has
  that numeric ID. find a tag's ID by looking at the URL of its page on
  wallhaven.cc. **cannot be combined with other terms in the same entry.**
- **wallhaven username**: `@username` — shows wallpapers uploaded by that user.
- **similar wallpapers**: `like:abc123z` — finds wallpapers similar to the one
  with that wallpaper ID (the alphanumeric ID from the wallhaven URL, e.g.
  `wallhaven.cc/w/abc123z`).
- **comma-separated list**: `nature,landscape,@username,like:abc123z` — the
  plugin picks one entry at random each time a new wallpaper is fetched, so each
  entry must be a valid standalone query.

if you are unsure what tags exist, browse [wallhaven.cc](https://wallhaven.cc)
and check the tags listed on any wallpaper page.

for more information about the wallhaven API, you can check the
[official documentation](https://wallhaven.cc/help/api).

### Saved Wallpapers

Build a personal collection of your favorite wallpapers with true offline use:

1. **Save wallpapers**: Right-click on the desktop → "Save Wallpaper" to
   download and store the current wallpaper locally.
2. **Use saved wallpapers only**: Enable this option in settings to cycle
   through your saved wallpapers without an internet connection.
3. **Loop or fetch new**: Choose whether to restart the cycle when all saved
   wallpapers have been shown, or automatically fetch new wallpapers from
   Wallhaven.
4. **Shuffle or sequential**: Display saved wallpapers in random order, or in
   the order they were saved.
5. **Manage collection**: Open the saved wallpapers folder from settings, or
   clear the entire collection (files included) with one click.

Saved wallpapers persist across plasmashell restarts and include thumbnail URLs
for fast preview loading in settings.

### Current known issues

- the plugin cannot be set as lock screen wallpaper.
  ([networking related](https://bugs.kde.org/show_bug.cgi?id=483094))
- the thumbnail in the wallpaper KCM does not change when the wallpaper changes,
  and always shows the first fetched wallpaper. Plasma issue because the KCM
  thumbnail is static by design and cannot be updated dynamically.
- the System Settings wallpaper KCM can crash when applying changes with this
  plugin active. Use the **right-click on the desktop → Configure Desktop and
  Wallpaper** menu instead, which is the stable way to configure the plugin.
  ([related issue](https://github.com/Blacksuan19/plasma-wallpaper-wallhaven-reborn/issues/2))

## Installation

### Arch Linux

Install the plugin from the
[AUR](https://aur.archlinux.org/packages/plasma6-applets-wallhaven-reborn-git)
(thanks to @cyqsimon for maintaining the package)

```bash
yay -S plasma6-applets-wallhaven-reborn-git
```

### KDE Store

Install the plugin from the KDE Store Plasma 6 version

- Right click on the Desktop > Configure Desktop and Wallpaper... > Get New
  Plugins
- Search for "Wallhaven Wallpaper Reborn", install and set it as your wallpaper.
- To set as Lock Screen wallpaper go to System settings > Screen Locking >
  Appearance: Configure...

### From source

installation requires `kpackagetool6` which can be found on the `kpackage`
package on arch based distros, `kpackagetool6` on Suse based distros, and
`kf6-kpackage` on debian based distros.

```bash
git clone https://github.com/Blacksuan19/plasma-wallpaper-wallhaven-reborn.git
cd plasma-wallpaper-wallhaven-reborn
kpackagetool6 --type Plasma/Wallpaper --install package/

# restart plasmashell
plasmashell --replace & disown
```

### Additional Setup

> [!IMPORTANT] If the wallpaper is not fetched or applied after installation,
> follow these steps before reporting a bug.

- Set the plugin as your wallpaper via **right-click on the desktop → Configure
  Desktop and Wallpaper** (do not use the System Settings app — see known
  issues).
- Close the settings window.
- Open the settings window again — a new wallpaper should be fetched.

If the wallpaper is still not fetched or applied:

- Refresh the wallpaper from the context menu or settings page.
- Restart the shell:

  ```bash
  plasmashell --replace & disown
  ```

## Reporting Bugs

Please use the
[issue tracker](https://github.com/Blacksuan19/plasma-wallpaper-wallhaven-reborn/issues/new/choose)
to report bugs. The bug report template will guide you through providing all the
necessary information.
