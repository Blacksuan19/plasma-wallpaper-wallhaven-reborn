import QtQuick
import "../../package/contents/ui/syncCoordinator.js" as SyncCoordinator

QtObject {
    id: root

    property string groupId
    property string instanceId
    property string currentUrl
    property int selectionCount: 0
    property int producerCalls: 0
    property string errorText

    function initialize(databaseName, targetGroupId) {
        SyncCoordinator.setDatabaseNameForTests(databaseName);
        groupId = targetGroupId;
        const registration = SyncCoordinator.registerInstance(groupId, {
            onSelection: function(selection) {
                currentUrl = selection.url;
                selectionCount += 1;
            }
        });
        instanceId = registration.instanceId;
        if (registration.hasSelection) {
            currentUrl = registration.selection.url;
            selectionCount += 1;
        }
        return instanceId !== "";
    }

    function requestSelection(url) {
        return SyncCoordinator.requestSelection(groupId, instanceId, function() {
            producerCalls += 1;
            return Promise.resolve({
                url: url,
                producerInstanceId: instanceId
            });
        }, function(error) {
            errorText = error.toString();
        });
    }

    function poll() {
        return SyncCoordinator.pollInstance(groupId, instanceId);
    }

    function unregister() {
        SyncCoordinator.unregisterInstance(groupId, instanceId);
        instanceId = "";
    }
}
