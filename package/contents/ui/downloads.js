function formatCommandError(stderr, stdout, exitCode) {
    let details = (stderr || stdout || ("Exit code: " + exitCode) || "Unknown error").toString();
    details = details.replace(/\s+/g, " ").trim();
    if (details.length > 160)
        details = details.slice(0, 157) + "...";
    return details;
}

function saveEntry(ctx, imageUrl, thumbnailUrl, localPath, isDark) {
    const normalizedLocalPath = ctx.utils.normalizePath(localPath || "");
    if (!normalizedLocalPath) {
        if (ctx.log)
            ctx.log("Skipping save entry because no local file was downloaded for: " + imageUrl);
        return;
    }
    const darkFlag = isDark === true ? "1" : isDark === false ? "0" : "";
    const savedEntry = imageUrl + "|||" + thumbnailUrl + "|||" + normalizedLocalPath + "|||" + darkFlag;
    let currentList = ctx.config.SavedWallpapers || [];
    const alreadySaved = currentList.some((entry) => {
        const parts = entry.split("|||");
        return parts[0] === imageUrl;
    });
    if (alreadySaved) {
        ctx.notify("Wallhaven Wallpaper", "Wallpaper already saved", "dialog-information", false);
        return;
    }
    let newList = currentList.slice();
    newList.push(savedEntry);
    ctx.config.SavedWallpapers = newList;
    ctx.writeConfig();
    if (ctx.log)
        ctx.log("Saved wallpaper: " + imageUrl + " (local: " + normalizedLocalPath + ")");

    ctx.notify("Wallhaven Wallpaper", "Wallpaper downloaded and saved! Total: " + newList.length, "plugin-wallpaper", false);
}

function queueDownload(ctx, imageUrl, thumbnailUrl, isDark) {
    const wallhavenId = ctx.utils.extractWallhavenId(imageUrl);
    if (!wallhavenId) {
        if (ctx.log)
            ctx.log("Could not extract Wallhaven ID from URL: " + imageUrl);
        ctx.notify("Wallhaven Wallpaper Error", "Could not determine a filename for this wallpaper", "dialog-error", true);
        return;
    }
    if (!ctx.savedDir) {
        if (ctx.log)
            ctx.log("Saved wallpapers directory is empty");
        ctx.notify("Wallhaven Wallpaper Error", "Download failed: saved wallpapers directory is unavailable", "dialog-error", true);
        return;
    }

    const localPath = ctx.savedDir + "/" + wallhavenId + ".jpg";
    if (ctx.log)
        ctx.log("Downloading wallpaper to: " + localPath);

    ctx.pendingDownloads[imageUrl] = {
        thumbnail: thumbnailUrl,
        localPath: localPath,
        wallhavenId: wallhavenId,
        isDark: isDark
    };
    const mkdirCmd = `mkdir -p "${ctx.savedDir}"`;
    ctx.exec(mkdirCmd);
}

function handleExecResult(ctx, sourceName, data) {
    const exitCode = data["exit code"];
    const stdout = data["stdout"];
    const stderr = data["stderr"];
    if (ctx.log)
        ctx.log("Command executed: " + sourceName);
    if (ctx.log)
        ctx.log("Exit code: " + exitCode + ", stdout: " + stdout + ", stderr: " + stderr);

    if (sourceName.startsWith("mkdir")) {
        if (exitCode !== 0) {
            const errorDetails = formatCommandError(stderr, stdout, exitCode);
            if (ctx.log)
                ctx.log("Failed to create directory: " + errorDetails);
            ctx.notify("Wallhaven Wallpaper Error", "Download failed: could not create saved wallpapers directory. " + errorDetails, "dialog-error", true);
            for (let url in ctx.pendingDownloads) {
                delete ctx.pendingDownloads[url];
                break;
            }
            ctx.disconnect(sourceName);
            return;
        }
        for (let url in ctx.pendingDownloads) {
            const info = ctx.pendingDownloads[url];
            const downloadCmd = `curl --fail --show-error --location --connect-timeout 10 --max-time 60 -o "${info.localPath}" "${url}"`;
            if (ctx.log)
                ctx.log("Starting download: " + downloadCmd);
            ctx.exec(downloadCmd);
            break;
        }
    } else if (sourceName.startsWith("curl")) {
        for (let url in ctx.pendingDownloads) {
            if (sourceName.includes(url)) {
                const info = ctx.pendingDownloads[url];
                if (exitCode === 0) {
                    if (ctx.log)
                        ctx.log("Download successful: " + info.localPath);
                    saveEntry(ctx, url, info.thumbnail, info.localPath, info.isDark);
                } else {
                    const errorDetails = formatCommandError(stderr, stdout, exitCode);
                    if (ctx.log)
                        ctx.log("Download failed: " + errorDetails);
                    ctx.notify("Wallhaven Wallpaper Error", "Download failed: " + errorDetails, "dialog-error", true);
                }
                delete ctx.pendingDownloads[url];
                break;
            }
        }
    }
    ctx.disconnect(sourceName);
}
