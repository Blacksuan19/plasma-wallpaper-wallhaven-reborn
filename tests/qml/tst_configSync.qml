import QtQuick
import QtTest

TestCase {
    id: testCase

    name: "ConfigSync"

    function i18n(text) {
        return text;
    }

    function i18nd(domain, text) {
        return text;
    }

    QtObject {
        id: fakeConfigDialog

        property bool allScreens: false
        property var configuration: null
        property bool needsSave: false

        function save() {}
    }

    Loader {
        id: configLoader
    }

    function initTestCase() {
        configLoader.setSource("../../package/contents/ui/config.qml", {
            configDialog: fakeConfigDialog
        });
        tryCompare(configLoader, "status", Loader.Ready);
        verify(configLoader.item !== null);
    }

    function test_plasmaAllScreensEnablesSharedGroup() {
        verify(!configLoader.item.cfg_SynchronizeScreens);
        compare(configLoader.item.cfg_SyncGroupId, "");

        fakeConfigDialog.allScreens = true;

        tryCompare(configLoader.item, "cfg_SynchronizeScreens", true);
        verify(configLoader.item.cfg_SyncGroupId.indexOf("wallhaven-") === 0);
    }
}
