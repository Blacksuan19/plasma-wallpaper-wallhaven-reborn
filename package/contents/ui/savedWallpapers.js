function saveCurrentWallpaper(ctx) {
    const currentUrl = ctx.currentUrl();
    if (!currentUrl || currentUrl === "" || currentUrl === "blackscreen.jpg") {
        ctx.notify("Wallhaven Wallpaper Error", "No valid wallpaper to save", "dialog-error", true);
        return;
    }
    const thumbnail = ctx.thumbnail();
    if (ctx.utils.isHttpUrl(currentUrl)) {
        ctx.notify("Wallhaven Wallpaper", "Downloading wallpaper...", "download", false);
        ctx.downloadWallpaper(currentUrl, thumbnail);
    } else {
        ctx.saveEntry(currentUrl, thumbnail, "");
    }
}

function loadFromSavedWallpapers(ctx) {
    const config = ctx.config;
    const savedList = config.SavedWallpapers || [];
    if (savedList.length === 0) {
        ctx.notify("Wallhaven Wallpaper", "No saved wallpapers found. Fetching from Wallhaven...", "plugin-wallpaper", false);
        ctx.fetchFromWallhaven("No saved wallpapers found. Fetching from Wallhaven...");
        return;
    }

    let shownList = config.ShownSavedWallpapers || [];
    if (shownList.length >= savedList.length) {
        if (config.CycleSavedWallpapers) {
            ctx.notify("Wallhaven Wallpaper", "Restarting saved wallpapers cycle", "plugin-wallpaper", false);
            config.ShownSavedWallpapers = [];
            ctx.writeConfig();
            shownList = [];
        } else {
            ctx.fetchFromWallhaven("All " + savedList.length + " saved wallpapers shown. Fetching new from Wallhaven...");
            return;
        }
    }

    let unshownWallpapers = savedList.filter((entry) => {
        return shownList.indexOf(entry) === -1;
    });
    let availableWallpapers = unshownWallpapers.filter((entry) => {
        const parsed = ctx.utils.parseSavedEntry(entry);
        return parsed.fullUrl !== ctx.state.lastLoadedUrl;
    });

    if (availableWallpapers.length === 0) {
        availableWallpapers = savedList.filter((entry) => {
            const parsed = ctx.utils.parseSavedEntry(entry);
            return parsed.fullUrl !== ctx.state.lastLoadedUrl;
        });
        if (availableWallpapers.length === 0) {
            if (config.CycleSavedWallpapers) {
                ctx.notify("Wallhaven Wallpaper", "Only one saved wallpaper available", "plugin-wallpaper", false);
                availableWallpapers = savedList.slice();
            } else {
                ctx.fetchFromWallhaven("Only one saved wallpaper. Fetching new from Wallhaven...");
                return;
            }
        }
        shownList = [];
    }

    let selectedEntry;
    if (config.ShuffleSavedWallpapers) {
        const randomIndex = Math.floor(Math.random() * availableWallpapers.length);
        selectedEntry = availableWallpapers[randomIndex];
    } else {
        selectedEntry = availableWallpapers[0];
    }

    const parsed = ctx.utils.parseSavedEntry(selectedEntry);
    const finalUrl = parsed.localPath ? "file://" + parsed.localPath : parsed.fullUrl;
    const thumbnailSource = parsed.localPath ? "file://" + parsed.localPath : parsed.thumbUrl;

    let newShownList = shownList.slice();
    newShownList.push(selectedEntry);
    config.ShownSavedWallpapers = newShownList;
    const source = parsed.localPath ? "local" : "online";
    ctx.notify("Wallhaven Wallpaper", "Loading saved wallpaper " + newShownList.length + " of " + savedList.length + " (" + source + ")", "plugin-wallpaper", false);

    ctx.setCurrentUrl(finalUrl);
    ctx.setLastValidImagePath(finalUrl);
    ctx.setThumbnail(thumbnailSource);
    ctx.writeConfig();
    ctx.loadImage();
    ctx.setLoading(false);
}
