import QtQuick
import QtTest
import "../../package/contents/ui/syncCoordinator.js" as SyncCoordinator

TestCase {
    name: "SyncCoordinator"

    function initTestCase() {
        SyncCoordinator.setDatabaseNameForTests("wallhaven-sync-unit-tests");
    }

    function init() {
        SyncCoordinator.resetForTests();
    }

    function test_coalescesRequestsAndBroadcastsOneSelection() {
        const firstSelections = [];
        const secondSelections = [];
        let producerCalls = 0;
        let resolveProducer;

        const first = SyncCoordinator.registerInstance("group-a", {
            onSelection: function(selection) {
                firstSelections.push(selection);
            }
        });
        const second = SyncCoordinator.registerInstance("group-a", {
            onSelection: function(selection) {
                secondSelections.push(selection);
            }
        });

        const started = SyncCoordinator.requestSelection("group-a", first.instanceId, function() {
            producerCalls += 1;
            return new Promise(function(resolve) {
                resolveProducer = resolve;
            });
        });
        const duplicateStarted = SyncCoordinator.requestSelection("group-a", second.instanceId, function() {
            producerCalls += 1;
            return Promise.resolve({url: "should-not-run"});
        });

        verify(started);
        verify(!duplicateStarted);
        compare(producerCalls, 1);

        resolveProducer({url: "https://example.test/shared.jpg"});
        tryVerify(function() {
            return firstSelections.length === 1 && secondSelections.length === 1;
        });
        compare(firstSelections[0].url, "https://example.test/shared.jpg");
        compare(secondSelections[0].url, "https://example.test/shared.jpg");
    }

    function test_lateInstanceCanReplayLastSelection() {
        SyncCoordinator.publishSelection("group-a", {url: "file:///shared.jpg"});

        const registration = SyncCoordinator.registerInstance("group-a", {});

        verify(registration.hasSelection);
        compare(registration.selection.url, "file:///shared.jpg");
    }

    function test_unregisteringRequestOwnerReleasesClaim() {
        const selections = [];
        let resolveFirst;
        const first = SyncCoordinator.registerInstance("group-a", {
            onSelection: function(selection) {
                selections.push(selection);
            }
        });
        const second = SyncCoordinator.registerInstance("group-a", {
            onSelection: function(selection) {
                selections.push(selection);
            }
        });

        verify(SyncCoordinator.requestSelection("group-a", first.instanceId, function() {
            return new Promise(function(resolve) {
                resolveFirst = resolve;
            });
        }));
        SyncCoordinator.unregisterInstance("group-a", first.instanceId);
        verify(SyncCoordinator.requestSelection("group-a", second.instanceId, function() {
            return Promise.resolve({url: "file:///second.jpg"});
        }));

        tryVerify(function() {
            return selections.length === 1;
        });
        compare(selections[0].url, "file:///second.jpg");

        resolveFirst({url: "file:///stale-first.jpg"});
        wait(0);
        compare(selections.length, 1);
    }

    function test_groupsRemainIndependent() {
        const groupASelections = [];
        const groupBSelections = [];
        SyncCoordinator.registerInstance("group-a", {
            onSelection: function(selection) {
                groupASelections.push(selection);
            }
        });
        SyncCoordinator.registerInstance("group-b", {
            onSelection: function(selection) {
                groupBSelections.push(selection);
            }
        });

        SyncCoordinator.publishSelection("group-a", {url: "file:///a.jpg"});

        compare(groupASelections.length, 1);
        compare(groupBSelections.length, 0);
    }
}
