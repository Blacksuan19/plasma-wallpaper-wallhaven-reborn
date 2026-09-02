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
 *   producerInstanceId?: number
 * }} WallpaperSelection
 */

/**
 * @typedef {{
 *   onSelection?: function(WallpaperSelection): void,
 *   onLeaderChanged?: function(boolean): void
 * }} SyncHandlers
 */

/**
 * @typedef {{
 *   members: Object.<string, SyncHandlers>,
 *   leaderId: number,
 *   inFlight: boolean,
 *   lastSelection: (WallpaperSelection|null)
 * }} SyncGroup
 */

/**
 * @typedef {{
 *   instanceId: number,
 *   isLeader: boolean,
 *   hasSelection: boolean,
 *   selection: (WallpaperSelection|null)
 * }} SyncRegistration
 */

/** @type {Object.<string, SyncGroup>} */
var groups = ({});

/** @type {number} */
var nextInstanceId = 1;

/**
 * @param {string} groupId
 * @returns {SyncGroup}
 */
function ensureGroup(groupId) {
    if (!groups[groupId]) {
        groups[groupId] = {
            members: ({}),
            leaderId: 0,
            inFlight: false,
            lastSelection: null
        };
    }
    return groups[groupId];
}

/**
 * @param {(SyncHandlers|null|undefined)} member
 * @param {boolean} isLeader
 * @returns {void}
 */
function notifyLeader(member, isLeader) {
    if (member && typeof member.onLeaderChanged === "function")
        member.onLeaderChanged(isLeader);
}

/**
 * @param {(SyncHandlers|null|undefined)} member
 * @param {WallpaperSelection} selection
 * @returns {void}
 */
function notifySelection(member, selection) {
    if (member && typeof member.onSelection === "function")
        member.onSelection(selection);
}

/**
 * @param {string} groupId
 * @param {(SyncHandlers|null|undefined)} handlers
 * @returns {SyncRegistration}
 */
function registerInstance(groupId, handlers) {
    const group = ensureGroup(groupId);
    const instanceId = nextInstanceId++;
    group.members[instanceId] = handlers || ({});

    if (!group.leaderId)
        group.leaderId = instanceId;

    const isLeader = group.leaderId === instanceId;
    notifyLeader(group.members[instanceId], isLeader);

    return {
        instanceId: instanceId,
        isLeader: isLeader,
        hasSelection: group.lastSelection !== null,
        selection: group.lastSelection
    };
}

/**
 * @param {string} groupId
 * @param {number} instanceId
 * @returns {void}
 */
function unregisterInstance(groupId, instanceId) {
    const group = groups[groupId];
    if (!group || !group.members[instanceId])
        return;

    delete group.members[instanceId];

    const memberIds = Object.keys(group.members);
    if (memberIds.length === 0) {
        delete groups[groupId];
        return;
    }

    if (group.leaderId === instanceId) {
        group.leaderId = Number(memberIds[0]);
        notifyLeader(group.members[group.leaderId], true);
    }
}

/**
 * @param {string} groupId
 * @param {WallpaperSelection} selection
 * @returns {void}
 */
function publishSelection(groupId, selection) {
    const group = ensureGroup(groupId);
    group.lastSelection = selection;
    Object.keys(group.members).forEach((instanceId) => {
        notifySelection(group.members[instanceId], selection);
    });
}

/**
 * @param {string} groupId
 * @returns {boolean}
 */
function hasSelection(groupId) {
    return !!(groups[groupId] && groups[groupId].lastSelection !== null);
}

/**
 * @param {string} groupId
 * @param {function(): (WallpaperSelection|Promise<WallpaperSelection|null>|null)} producer
 * @param {(function(*): void|null|undefined)} onError
 * @returns {boolean}
 */
function requestSelection(groupId, producer, onError) {
    const group = ensureGroup(groupId);
    if (group.inFlight)
        return false;

    group.inFlight = true;
    /** @type {(WallpaperSelection|Promise<WallpaperSelection|null>|null)} */
    let result;
    try {
        result = producer();
    } catch (error) {
        group.inFlight = false;
        if (typeof onError === "function")
            onError(error);
        return true;
    }

    Promise.resolve(result).then((selection) => {
        if (groups[groupId] !== group)
            return;

        group.inFlight = false;
        if (selection)
            publishSelection(groupId, selection);
    }).catch((error) => {
        if (groups[groupId] !== group)
            return;

        group.inFlight = false;
        if (typeof onError === "function")
            onError(error);
    });
    return true;
}

/** @returns {void} */
function resetForTests() {
    groups = ({});
    nextInstanceId = 1;
}
