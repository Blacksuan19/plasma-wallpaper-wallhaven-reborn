/**
 * @typedef {{
 *   SavedWallpapers?: string[],
 *   FollowSystemTheme?: boolean,
 *   CycleSavedWallpapers?: boolean,
 *   ShuffleSavedWallpapers?: boolean
 * }} SavedWallpaperConfig
 */

/**
 * @typedef {{
 *   lastLoadedUrl: string
 * }} SavedWallpaperState
 */

/**
 * @typedef {{
 *   fullUrl: string,
 *   thumbUrl: string,
 *   localPath: string,
 *   isDark: (boolean|null)
 * }} SavedWallpaperEntry
 */

/**
 * @typedef {{
 *   isHttpUrl: function(string): boolean,
 *   normalizePath: function(string): string,
 *   parseSavedEntry: function(string): SavedWallpaperEntry
 * }} SavedWallpaperUtils
 */

/**
 * @typedef {{
 *   notify: function(string, string, string, boolean=): void,
 *   currentUrl: function(): string,
 *   thumbnail: function(): string,
 *   downloadWallpaper: function(string, string, (boolean|null|undefined)): void,
 *   isDark: (boolean|null),
 *   utils: SavedWallpaperUtils
 * }} SavedWallpaperSaveContext
 */

/**
 * @typedef {{
 *   config: SavedWallpaperConfig,
 *   state: SavedWallpaperState,
 *   getShownList: function(): string[],
 *   systemDarkMode: boolean,
 *   utils: SavedWallpaperUtils,
 *   log: function(string): void
 * }} SavedWallpaperSelectionContext
 */

/**
 * @typedef {{
 *   type: "fetch",
 *   reason: string,
 *   shownList: string[],
 *   notifications: string[]
 * }} SavedWallpaperFetchResult
 */

/**
 * @typedef {{
 *   type: "selection",
 *   url: string,
 *   thumbnail: string,
 *   shownList: string[],
 *   notifications: string[]
 * }} SavedWallpaperSelectionResult
 */

/**
 * @typedef {SavedWallpaperFetchResult|SavedWallpaperSelectionResult} SavedWallpaperResult
 */

/**
 * @param {SavedWallpaperSaveContext} ctx
 * @returns {void}
 */
function saveCurrentWallpaper(ctx) {
    const currentUrl = ctx.currentUrl();
    if (!currentUrl || currentUrl === "" || currentUrl === "blackscreen.jpg") {
        ctx.notify("Wallhaven Wallpaper Error", "No valid wallpaper to save", "dialog-error", true);
        return;
    }
    const thumbnail = ctx.thumbnail();
    if (ctx.utils.isHttpUrl(currentUrl)) {
        ctx.notify("Wallhaven Wallpaper", "Downloading wallpaper...", "download", false);
        ctx.downloadWallpaper(currentUrl, thumbnail, ctx.isDark);
    } else {
        ctx.notify("Wallhaven Wallpaper Error", "Only wallpapers downloaded from Wallhaven can be saved", "dialog-error", true);
    }
}

/**
 * Select the next saved wallpaper without applying it to a specific screen.
 * This lets one Plasma wallpaper instance make the choice and share it with
 * the other synchronized instances.
 *
 * @param {SavedWallpaperSelectionContext} ctx
 * @returns {SavedWallpaperResult}
 */
function selectSavedWallpaper(ctx) {
    const config = ctx.config;
    const fullSavedList = config.SavedWallpapers || [];
    if (fullSavedList.length === 0) {
        return {
            type: "fetch",
            reason: "No saved wallpapers found. Fetching from Wallhaven...",
            shownList: [],
            notifications: []
        };
    }

    const notifications = [];

    // Filter to dark wallpapers when FollowSystemTheme is enabled and system is in dark mode.
    // Entries with unknown darkness (isDark === null, e.g. older saved entries) are always included.
    let savedList = fullSavedList;
    if (config.FollowSystemTheme && ctx.systemDarkMode) {
        const darkList = fullSavedList.filter((entry) => {
            const parsed = ctx.utils.parseSavedEntry(entry);
            return parsed.isDark !== false; // include dark (true) and unknown (null)
        });
        if (darkList.length > 0) {
            savedList = darkList;
        } else {
            ctx.log("No dark saved wallpapers found, cycling all saved wallpapers");
        }
    }

    let shownList = ctx.getShownList();
    if (shownList.length >= savedList.length) {
        if (config.CycleSavedWallpapers) {
            notifications.push("Restarting saved wallpapers cycle");
            shownList = [];
        } else {
            return {
                type: "fetch",
                reason: "All " + savedList.length + " saved wallpapers shown. Fetching new from Wallhaven...",
                shownList: [],
                notifications: notifications
            };
        }
    }

    const lastLoadedUrl = ctx.state.lastLoadedUrl || "";
    const lastLoadedPath = ctx.utils.normalizePath(lastLoadedUrl);
    const isCurrentEntry = (entry) => {
        const parsed = ctx.utils.parseSavedEntry(entry);
        if (ctx.utils.isHttpUrl(lastLoadedUrl))
            return parsed.fullUrl === lastLoadedUrl;
        if (lastLoadedPath && parsed.localPath)
            return parsed.localPath === lastLoadedPath;
        return parsed.fullUrl === lastLoadedUrl;
    };
    const isShownEntry = (entry) => {
        return shownList.indexOf(entry) !== -1;
    };

    let unshownWallpapers = savedList.filter((entry) => {
        return !isShownEntry(entry);
    });

    if (!config.CycleSavedWallpapers && unshownWallpapers.length === 0) {
        return {
            type: "fetch",
            reason: "All " + savedList.length + " saved wallpapers shown. Fetching new from Wallhaven...",
            shownList: [],
            notifications: notifications
        };
    }

    const pickNextSequential = () => {
        const currentIndex = savedList.findIndex((entry) => {
            return isCurrentEntry(entry);
        });
        const startIndex = currentIndex >= 0 ? currentIndex : -1;
        for (let offset = 1; offset <= savedList.length; offset++) {
            const idx = (startIndex + offset) % savedList.length;
            const entry = savedList[idx];
            if (isCurrentEntry(entry))
                continue;
            if (unshownWallpapers.length > 0 && !isShownEntry(entry))
                return entry;
            if (unshownWallpapers.length === 0)
                return entry;
        }
        return "";
    };

    let selectedEntry = "";
    if (config.ShuffleSavedWallpapers) {
        let availableWallpapers = unshownWallpapers.filter((entry) => {
            return !isCurrentEntry(entry);
        });
        if (availableWallpapers.length === 0) {
            if (config.CycleSavedWallpapers) {
                notifications.push("Only one saved wallpaper available");
                availableWallpapers = savedList.filter((entry) => {
                    return !isCurrentEntry(entry);
                });
                if (availableWallpapers.length === 0)
                    availableWallpapers = savedList.slice();
                shownList = [];
            } else {
                return {
                    type: "fetch",
                    reason: "Only one saved wallpaper. Fetching new from Wallhaven...",
                    shownList: [],
                    notifications: notifications
                };
            }
        }
        const randomIndex = Math.floor(Math.random() * availableWallpapers.length);
        selectedEntry = availableWallpapers[randomIndex];
    } else {
        selectedEntry = pickNextSequential();
        if (!selectedEntry) {
            if (config.CycleSavedWallpapers) {
                shownList = [];
                unshownWallpapers = savedList.slice();
                selectedEntry = pickNextSequential();
                if (!selectedEntry) {
                    notifications.push("Only one saved wallpaper available");
                    selectedEntry = savedList[0];
                }
            } else {
                return {
                    type: "fetch",
                    reason: "All " + savedList.length + " saved wallpapers shown. Fetching new from Wallhaven...",
                    shownList: [],
                    notifications: notifications
                };
            }
        }
    }

    const parsed = ctx.utils.parseSavedEntry(selectedEntry);
    const finalUrl = parsed.localPath ? "file://" + parsed.localPath : parsed.fullUrl;
    const thumbnailSource = parsed.localPath ? "file://" + parsed.localPath : parsed.thumbUrl;

    let newShownList = shownList.slice();
    newShownList.push(selectedEntry);
    const source = parsed.localPath ? "local" : "online";
    const selectedIndex = savedList.indexOf(selectedEntry) + 1;
    notifications.push("Loading saved wallpaper " + selectedIndex + " of " + savedList.length + " (" + source + ")");

    return {
        type: "selection",
        url: finalUrl,
        thumbnail: thumbnailSource,
        shownList: newShownList,
        notifications: notifications
    };
}
