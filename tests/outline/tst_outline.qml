import QtQuick
import QtTest
import "../../plasma/outline" as Outline

TestCase {
    id: testCase
    name: "SnapPreview"
    when: windowShown
    width: 1000
    height: 800
    visible: true

    Component {
        id: previewComponent
        Outline.SnapPreview {
            targetGeometry: Qt.rect(0, 0, 960, 1040)
            visualParentGeometry: Qt.rect(200, 100, 500, 400)
            animationDuration: 160
        }
    }

    function createPreview(properties) {
        return createTemporaryObject(previewComponent, testCase, properties || {});
    }

    function verifyInside(rect, viewport) {
        verify(rect.x >= viewport.x);
        verify(rect.y >= viewport.y);
        verify(rect.x + rect.width <= viewport.x + viewport.width);
        verify(rect.y + rect.height <= viewport.y + viewport.height);
    }

    function snapshot(rect) {
        return Qt.rect(rect.x, rect.y, rect.width, rect.height);
    }

    function test_initialAnimation() {
        const p = createPreview();
        p.active = true;
        verify(p.animating);
        const bounds = snapshot(p.viewport);
        const start = snapshot(p.frameGeometry);
        wait(60);
        verify(p.frameGeometry.width > start.width);
        verify(p.frameGeometry.width < 944);
        compare(p.viewport, bounds, "the backing surface must not resize per frame");
        verifyInside(p.frameGeometry, bounds);
        tryCompare(p, "animating", false);
        compare(p.frameGeometry, Qt.rect(8, 8, 944, 1024));
    }

    function test_retargetWithoutJump() {
        const p = createPreview();
        p.active = true;
        wait(60);
        const current = snapshot(p.frameGeometry);
        p.targetGeometry = Qt.rect(960, 0, 960, 1040);
        compare(p.frameGeometry, current);
        verifyInside(current, p.viewport);
        verifyInside(Qt.rect(968, 8, 944, 1024), p.viewport);
        tryCompare(p, "animating", false);
        compare(p.frameGeometry, Qt.rect(968, 8, 944, 1024));
    }

    function test_duplicateTargetDoesNotRestart() {
        const p = createPreview();
        p.active = true;
        wait(80);
        p.moveToTarget(false);
        wait(100);
        verify(!p.animating);
    }

    function test_negativeMonitorOrigin() {
        const p = createPreview({
            targetGeometry: Qt.rect(-1920, -1080, 960, 1040),
            visualParentGeometry: Qt.rect(-1700, -900, 500, 400)
        });
        p.active = true;
        verify(p.viewport.x < -1920);
        verify(p.viewport.y < -1080);
        verify(p.viewport.width < 1100, "surface must not span unrelated monitors");
        verifyInside(p.frameGeometry, p.viewport);
        tryCompare(p, "animating", false);
        compare(p.frameGeometry, Qt.rect(-1912, -1072, 944, 1024));
    }

    function test_noParentAndReducedMotion_data() {
        return [
            {tag: "keyboard", properties: {visualParentGeometry: Qt.rect(0, 0, 0, 0)}},
            {tag: "disabled", properties: {animationEnabled: false}},
            {tag: "zero-duration", properties: {animationDuration: 0}}
        ];
    }

    function test_noParentAndReducedMotion(data) {
        const p = createPreview(data.properties);
        p.active = true;
        verify(!p.animating);
        compare(p.frameGeometry, Qt.rect(8, 8, 944, 1024));
    }

    function test_hideAndReuse() {
        const p = createPreview();
        p.active = true;
        wait(40);
        p.active = false;
        verify(!p.animating);
        const hiddenFrame = snapshot(p.frameGeometry);
        p.targetGeometry = Qt.rect(960, 0, 960, 1040);
        wait(40);
        compare(p.frameGeometry, hiddenFrame);
        p.active = true;
        verify(p.animating);
        tryCompare(p, "animating", false);
        compare(p.frameGeometry, Qt.rect(968, 8, 944, 1024));
    }

    function test_fractionalGeometry() {
        const p = createPreview({animationEnabled: false,
            targetGeometry: Qt.rect(-959.5, 0.25, 959.5, 1039.5)});
        p.active = true;
        compare(p.frameGeometry, Qt.rect(-951.5, 8.25, 943.5, 1023.5));
        verifyInside(p.frameGeometry, p.viewport);
    }

    function test_initiallyActive() {
        const p = createPreview({active: true});
        tryCompare(p, "animating", false);
        compare(p.frameGeometry, Qt.rect(8, 8, 944, 1024));
    }

    function test_renderedReflection() {
        const p = createPreview({
            animationEnabled: false,
            targetGeometry: Qt.rect(100, 100, 800, 600),
            reflectionGeometry: Qt.rect(0, 0, 1000, 800),
            reflectionSource: Qt.resolvedUrl("reflection.svg")
        });
        p.active = true;
        const frame = findChild(p, "snapFrame");
        tryCompare(findChild(p, "snapReflection"), "status", Image.Ready);
        verify(waitForRendering(frame));
        const image = grabImage(frame);
        // The reflection stays anchored to desktop coordinates, including
        // after retargeting; it must not stretch to the preview's rectangle.
        compare(image.red(100, 100), 224);
        compare(image.blue(100, 100), 48);
        compare(image.red(600, 100), 32);
        compare(image.blue(600, 100), 224);
        p.targetGeometry = Qt.rect(600, 100, 300, 600);
        verify(waitForRendering(frame));
        const moved = grabImage(frame);
        compare(moved.red(100, 100), 32);
        compare(moved.blue(100, 100), 224);
    }
}
