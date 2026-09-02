import QtQuick
import QtTest
import "../../package/contents/ui/savedWallpapers.js" as SavedWallpapers
import "../../package/contents/ui/utils.js" as Utils

TestCase {
    name: "SavedWallpapers"

    function makeContext(lastLoadedUrl, shownList) {
        return {
            config: {
                SavedWallpapers: [
                    "https://w.wallhaven.cc/full/aa/wallhaven-aa1111.jpg|||https://th.wallhaven.cc/small/aa/aa1111.jpg|||/tmp/a.jpg|||0",
                    "https://w.wallhaven.cc/full/bb/wallhaven-bb2222.jpg|||https://th.wallhaven.cc/small/bb/bb2222.jpg|||/tmp/b.jpg|||1"
                ],
                FollowSystemTheme: false,
                CycleSavedWallpapers: true,
                ShuffleSavedWallpapers: false
            },
            state: {
                lastLoadedUrl: lastLoadedUrl
            },
            getShownList: function() {
                return shownList;
            },
            systemDarkMode: false,
            utils: Utils,
            log: function() {}
        };
    }

    function test_selectionIsReturnedWithoutScreenSideEffects() {
        const result = SavedWallpapers.selectSavedWallpaper(makeContext("file:///tmp/a.jpg", []));

        compare(result.type, "selection");
        compare(result.url, "file:///tmp/b.jpg");
        compare(result.thumbnail, "file:///tmp/b.jpg");
        compare(result.shownList.length, 1);
    }

    function test_exhaustedNonCyclingListRequestsRemoteWallpaper() {
        const context = makeContext("file:///tmp/b.jpg", []);
        context.config.CycleSavedWallpapers = false;
        context.getShownList = function() {
            return context.config.SavedWallpapers.slice();
        };

        const result = SavedWallpapers.selectSavedWallpaper(context);

        compare(result.type, "fetch");
        compare(result.shownList.length, 0);
        verify(result.reason.indexOf("Fetching new from Wallhaven") !== -1);
    }
}
