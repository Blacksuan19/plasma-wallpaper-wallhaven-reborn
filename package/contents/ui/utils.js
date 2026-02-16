function normalizePath(path) {
    if (!path)
        return "";

    const text = (typeof path === "string") ? path : path.toString();
    return text.startsWith("file://") ? text.slice("file://".length) : text;
}

function isHttpUrl(url) {
    if (!url)
        return false;

    return url.toString().startsWith("http");
}

function extractWallhavenId(url) {
    const match = url.match(/wallhaven-([a-zA-Z0-9]+)/);
    return match ? match[1] : null;
}

function parseSavedEntry(entry) {
    const parts = entry.split("|||");
    const fullUrl = parts[0];
    const thumbUrl = parts.length > 1 ? parts[1] : fullUrl;
    const localPath = parts.length > 2 ? normalizePath(parts[2]) : "";

    return {
        fullUrl: fullUrl,
        thumbUrl: thumbUrl,
        localPath: localPath
    };
}

function buildBinaryParameter(config, paramName, configKeys) {
    let result = "";
    for (let i = 0; i < configKeys.length; i++) {
        result += config[configKeys[i]] ? "1" : "0";
    }
    return `${paramName}=${result}`;
}

function buildRatioParameter(config) {
    if (config.RatioAny)
        return "";

    var ratios = [];
    if (config.Ratio169)
        ratios.push("16x9");

    if (config.Ratio1610)
        ratios.push("16x10");

    if (config.RatioCustom)
        ratios.push(config.RatioCustomValue);

    return ratios.length > 0 ? `ratios=${ratios.join(',')}&` : "";
}

function buildQueryParameter(config, systemDarkMode, currentSearchTermIndex) {
    var userQuery = config.Query || "";
    let terms = userQuery.split(",");
    let termIndex = Math.floor(Math.random() * terms.length);
    if (termIndex === currentSearchTermIndex)
        termIndex = (termIndex + 1) % terms.length;

    let finalQuery = terms[termIndex].trim();
    if (config.FollowSystemTheme && systemDarkMode)
        finalQuery = (finalQuery ? finalQuery + "" : "") + "+dark";

    return {
        query: finalQuery,
        nextIndex: termIndex,
        queryParam: `q=${encodeURIComponent(finalQuery)}`
    };
}
