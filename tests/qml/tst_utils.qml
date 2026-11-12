import QtQuick
import QtTest
import "../../package/contents/ui/utils.js" as Utils

TestCase {
    name: "Utils"

    function isPermutationOfRange(values, count) {
        if (values.length !== count)
            return false;

        const seen = [];
        for (let i = 0; i < count; i++)
            seen.push(false);

        for (let i = 0; i < values.length; i++) {
            const value = values[i];
            if (value < 0 || value >= count || seen[value])
                return false;
            seen[value] = true;
        }
        return true;
    }

    function test_shuffledRangeHandlesEmptyAndSingleValues() {
        compare(Utils.shuffledRange(0).length, 0);
        compare(Utils.shuffledRange(1).join(","), "0");
    }

    function test_shuffledRangeReturnsEveryIndexExactlyOnce() {
        for (let count = 0; count <= 20; count++)
            verify(isPermutationOfRange(Utils.shuffledRange(count), count));
    }

    function test_shuffledRangeProducesDifferentOrders() {
        let sawAscending = false;
        let sawDescending = false;

        for (let i = 0; i < 50; i++) {
            const order = Utils.shuffledRange(2).join(",");
            if (order === "0,1")
                sawAscending = true;
            if (order === "1,0")
                sawDescending = true;
        }

        verify(sawAscending);
        verify(sawDescending);
    }
}
