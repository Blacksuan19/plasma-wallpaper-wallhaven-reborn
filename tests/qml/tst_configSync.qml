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

    QtObject {
        id: fakeDesktopConfigDialog

        property var configuration: null

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

    function init() {
        configLoader.item.configDialog = fakeConfigDialog;
        fakeConfigDialog.needsSave = false;
        fakeConfigDialog.allScreens = false;
        configLoader.item.cfg_SynchronizeScreens = false;
        configLoader.item.cfg_SyncGroupId = "";
    }

    function setSharedGroup() {
        configLoader.item.cfg_SynchronizeScreens = true;
        configLoader.item.cfg_SyncGroupId = "shared-group";
    }

    function test_individualChangesDetachScreenFromSharedGroup() {
        setSharedGroup();

        compare(configLoader.item.cfg_SynchronizeScreens, true);
        compare(configLoader.item.cfg_SyncGroupId, "shared-group");

        fakeConfigDialog.needsSave = true;

        tryCompare(configLoader.item, "cfg_SynchronizeScreens", false);
        compare(configLoader.item.cfg_SyncGroupId, "");
    }

    function test_individualSaveDetachesScreenFromSharedGroup() {
        setSharedGroup();

        configLoader.item.saveConfig();

        compare(configLoader.item.cfg_SynchronizeScreens, false);
        compare(configLoader.item.cfg_SyncGroupId, "");
    }

    function test_rightClickSaveDetachesScreenFromSharedGroup() {
        setSharedGroup();
        configLoader.item.configDialog = fakeDesktopConfigDialog;

        configLoader.item.saveConfig();

        compare(configLoader.item.cfg_SynchronizeScreens, false);
        compare(configLoader.item.cfg_SyncGroupId, "");
    }

    function test_plasmaAllScreensCreatesAndReleasesSharedGroup() {
        fakeConfigDialog.allScreens = true;

        tryCompare(configLoader.item, "cfg_SynchronizeScreens", true);
        verify(configLoader.item.cfg_SyncGroupId.indexOf("wallhaven-") === 0);

        fakeConfigDialog.allScreens = false;

        tryCompare(configLoader.item, "cfg_SynchronizeScreens", false);
        compare(configLoader.item.cfg_SyncGroupId, "");
    }
}
