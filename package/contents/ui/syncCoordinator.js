.pragma library
.import QtQuick.LocalStorage 2.0 as Sql

/**
 * @typedef {{
 *   kind?: ("remote"|"saved"),
 *   url: string,
 *   thumbnail?: string,
 *   colors?: string[],
 *   currentPage?: number,
 *   currentIndex?: number,
 *   currentSearchTermIndex?: number,
 *   shownList?: string[],
 *   producerInstanceId?: string
 * }} WallpaperSelection
 */

/**
 * @typedef {{
 *   onSelection?: function(WallpaperSelection): void
 * }} SyncHandlers
 */

/**
 * @typedef {{
 *   groupId: string,
 *   handlers: SyncHandlers,
 *   lastSeenVersion: number
 * }} LocalInstance
 */

/**
 * @typedef {{
 *   instanceId: string,
 *   hasSelection: boolean,
 *   selection: (WallpaperSelection|null)
 * }} SyncRegistration
 */

const databaseVersion = "";
const requestTimeoutMs = 120000;

/** @type {string} */
var databaseName = "wallhaven-wallpaper-sync";

/** @type {*} */
var database = null;

/** @type {Object.<string, LocalInstance>} */
var localInstances = ({});

/**
 * @returns {*}
 */
function openDatabase() {
    if (database)
        return database;

    database = Sql.LocalStorage.openDatabaseSync(databaseName, databaseVersion, "Wallhaven wallpaper synchronization", 1048576, (db) => {
        db.transaction((tx) => {
            tx.executeSql("CREATE TABLE IF NOT EXISTS sync_groups (group_id TEXT PRIMARY KEY, selection_version INTEGER NOT NULL DEFAULT 0, selection_json TEXT, request_owner TEXT, request_started INTEGER NOT NULL DEFAULT 0)");
        });
    });
    database.transaction((tx) => {
        tx.executeSql("PRAGMA busy_timeout = 2000");
        tx.executeSql("CREATE TABLE IF NOT EXISTS sync_groups (group_id TEXT PRIMARY KEY, selection_version INTEGER NOT NULL DEFAULT 0, selection_json TEXT, request_owner TEXT, request_started INTEGER NOT NULL DEFAULT 0)");
    });
    return database;
}

/**
 * @param {*} tx
 * @param {string} groupId
 * @returns {void}
 */
function ensureGroup(tx, groupId) {
    tx.executeSql("INSERT OR IGNORE INTO sync_groups (group_id) VALUES (?)", [groupId]);
}

/**
 * @param {(string|null|undefined)} json
 * @returns {WallpaperSelection|null}
 */
function parseSelection(json) {
    if (!json)
        return null;

    try {
        return JSON.parse(json);
    } catch (error) {
        console.warn("Wallhaven Wallpaper: Ignoring invalid synchronized selection: " + error);
        return null;
    }
}

/**
 * @returns {string}
 */
function createInstanceId() {
    return Date.now().toString(36) + "-" + Math.floor(Math.random() * 0x100000000).toString(36);
}

/**
 * @param {string} groupId
 * @returns {{version: number, selection: (WallpaperSelection|null)}}
 */
function readSelection(groupId) {
    let version = 0;
    let selection = null;
    openDatabase().readTransaction((tx) => {
        const result = tx.executeSql("SELECT selection_version, selection_json FROM sync_groups WHERE group_id = ?", [groupId]);
        if (result.rows.length > 0) {
            version = Number(result.rows.item(0).selection_version) || 0;
            selection = parseSelection(result.rows.item(0).selection_json);
        }
    });
    return {
        version: version,
        selection: selection
    };
}

/**
 * @param {string} groupId
 * @param {(SyncHandlers|null|undefined)} handlers
 * @returns {SyncRegistration}
 */
function registerInstance(groupId, handlers) {
    openDatabase().transaction((tx) => {
        ensureGroup(tx, groupId);
    });

    const state = readSelection(groupId);
    const instanceId = createInstanceId();
    localInstances[instanceId] = {
        groupId: groupId,
        handlers: handlers || ({}),
        lastSeenVersion: state.version
    };

    return {
        instanceId: instanceId,
        hasSelection: state.selection !== null,
        selection: state.selection
    };
}

/**
 * @param {string} groupId
 * @param {string} instanceId
 * @returns {void}
 */
function unregisterInstance(groupId, instanceId) {
    releaseRequest(groupId, instanceId);
    delete localInstances[instanceId];
}

/**
 * @param {string} groupId
 * @returns {boolean}
 */
function hasSelection(groupId) {
    return readSelection(groupId).selection !== null;
}

/**
 * @param {string} groupId
 * @param {WallpaperSelection} selection
 * @param {(string|null)} requestOwner
 * @returns {number}
 */
function storeSelection(groupId, selection, requestOwner) {
    let version = 0;
    openDatabase().transaction((tx) => {
        ensureGroup(tx, groupId);
        let result;
        if (requestOwner) {
            result = tx.executeSql("UPDATE sync_groups SET selection_version = selection_version + 1, selection_json = ?, request_owner = NULL, request_started = 0 WHERE group_id = ? AND request_owner = ?", [JSON.stringify(selection), groupId, requestOwner]);
            if (result.rowsAffected === 0)
                return;
        } else {
            tx.executeSql("UPDATE sync_groups SET selection_version = selection_version + 1, selection_json = ?, request_owner = NULL, request_started = 0 WHERE group_id = ?", [JSON.stringify(selection), groupId]);
        }

        result = tx.executeSql("SELECT selection_version FROM sync_groups WHERE group_id = ?", [groupId]);
        version = Number(result.rows.item(0).selection_version) || 0;
    });
    return version;
}

/**
 * Notify instances belonging to this JavaScript engine immediately. Instances
 * in other QML engines receive the same selection from pollInstance().
 *
 * @param {string} groupId
 * @param {WallpaperSelection} selection
 * @param {number} version
 * @returns {void}
 */
function notifyLocalInstances(groupId, selection, version) {
    Object.keys(localInstances).forEach((instanceId) => {
        const instance = localInstances[instanceId];
        if (instance.groupId !== groupId)
            return;

        instance.lastSeenVersion = version;
        if (typeof instance.handlers.onSelection === "function")
            instance.handlers.onSelection(selection);
    });
}

/**
 * @param {string} groupId
 * @param {WallpaperSelection} selection
 * @returns {void}
 */
function publishSelection(groupId, selection) {
    const version = storeSelection(groupId, selection, null);
    if (version > 0)
        notifyLocalInstances(groupId, selection, version);
}

/**
 * @param {string} groupId
 * @param {string} instanceId
 * @returns {boolean}
 */
function claimRequest(groupId, instanceId) {
    const now = Date.now();
    const expiredBefore = now - requestTimeoutMs;
    let claimed = false;
    openDatabase().transaction((tx) => {
        ensureGroup(tx, groupId);
        const result = tx.executeSql("UPDATE sync_groups SET request_owner = ?, request_started = ? WHERE group_id = ? AND (request_owner IS NULL OR request_started < ?)", [instanceId, now, groupId, expiredBefore]);
        claimed = result.rowsAffected === 1;
    });
    return claimed;
}

/**
 * @param {string} groupId
 * @param {string} instanceId
 * @returns {void}
 */
function releaseRequest(groupId, instanceId) {
    openDatabase().transaction((tx) => {
        tx.executeSql("UPDATE sync_groups SET request_owner = NULL, request_started = 0 WHERE group_id = ? AND request_owner = ?", [groupId, instanceId]);
    });
}

/**
 * @param {string} groupId
 * @param {string} instanceId
 * @param {function(): (WallpaperSelection|Promise<WallpaperSelection|null>|null)} producer
 * @param {(function(*): void|null|undefined)} onError
 * @returns {boolean}
 */
function requestSelection(groupId, instanceId, producer, onError) {
    let claimed = false;
    try {
        claimed = claimRequest(groupId, instanceId);
    } catch (error) {
        if (typeof onError === "function")
            onError(error);
        return false;
    }
    if (!claimed)
        return false;

    /** @type {(WallpaperSelection|Promise<WallpaperSelection|null>|null)} */
    let result;
    try {
        result = producer();
    } catch (error) {
        releaseRequest(groupId, instanceId);
        if (typeof onError === "function")
            onError(error);
        return true;
    }

    Promise.resolve(result).then((selection) => {
        if (!selection) {
            releaseRequest(groupId, instanceId);
            return;
        }

        const version = storeSelection(groupId, selection, instanceId);
        if (version > 0)
            notifyLocalInstances(groupId, selection, version);
    }).catch((error) => {
        releaseRequest(groupId, instanceId);
        if (typeof onError === "function")
            onError(error);
    });
    return true;
}

/**
 * @param {string} groupId
 * @param {string} instanceId
 * @returns {boolean}
 */
function pollInstance(groupId, instanceId) {
    const instance = localInstances[instanceId];
    if (!instance)
        return false;

    const state = readSelection(groupId);
    if (!state.selection || state.version <= instance.lastSeenVersion)
        return false;

    instance.lastSeenVersion = state.version;
    if (typeof instance.handlers.onSelection === "function")
        instance.handlers.onSelection(state.selection);
    return true;
}

/**
 * Change the database identifier before the first access in test processes.
 *
 * @param {string} name
 * @returns {void}
 */
function setDatabaseNameForTests(name) {
    databaseName = name;
    database = null;
    localInstances = ({});
}

/** @returns {void} */
function resetForTests() {
    openDatabase().transaction((tx) => {
        tx.executeSql("DELETE FROM sync_groups");
    });
    localInstances = ({});
}
