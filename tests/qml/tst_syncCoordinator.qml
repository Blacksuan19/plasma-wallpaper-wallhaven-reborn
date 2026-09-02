import QtQuick
import QtTest
import "../../package/contents/ui/syncCoordinator.js" as SyncCoordinator

TestCase {
    name: "SyncCoordinator"

    function init() {
        SyncCoordinator.resetForTests();
    }

    function test_coalescesRequestsAndBroadcastsOneSelection() {
        const firstSelections = [];
        const secondSelections = [];
        let producerCalls = 0;
        let resolveProducer;

        SyncCoordinator.registerInstance("group-a", {
            onSelection: function(selection) {
                firstSelections.push(selection);
            }
        });
        SyncCoordinator.registerInstance("group-a", {
            onSelection: function(selection) {
                secondSelections.push(selection);
            }
        });

        const started = SyncCoordinator.requestSelection("group-a", function() {
            producerCalls += 1;
            return new Promise(function(resolve) {
                resolveProducer = resolve;
            });
        });
        const duplicateStarted = SyncCoordinator.requestSelection("group-a", function() {
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

    function test_leaderMovesWhenFirstInstanceLeaves() {
        const leadershipChanges = [];
        const first = SyncCoordinator.registerInstance("group-a", {
            onLeaderChanged: function(isLeader) {
                leadershipChanges.push("first:" + isLeader);
            }
        });
        const second = SyncCoordinator.registerInstance("group-a", {
            onLeaderChanged: function(isLeader) {
                leadershipChanges.push("second:" + isLeader);
            }
        });

        verify(first.isLeader);
        verify(!second.isLeader);
        SyncCoordinator.unregisterInstance("group-a", first.instanceId);

        compare(leadershipChanges[0], "first:true");
        compare(leadershipChanges[1], "second:false");
        compare(leadershipChanges[2], "second:true");
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
