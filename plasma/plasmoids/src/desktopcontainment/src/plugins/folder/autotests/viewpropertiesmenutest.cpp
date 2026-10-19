/*
    SPDX-FileCopyrightText: 2017 Klarälvdalens Datakonsult AB a KDAB Group company <info@kdab.com>
    SPDX-FileContributor: 2017 Laurent Montel <laurent.montel@kdab.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "viewpropertiesmenutest.h"
#include "viewpropertiesmenu.h"
#include <QTest>

#include <KDirModel>

QTEST_MAIN(ViewPropertiesMenuTest)

void ViewPropertiesMenuTest::shouldHaveDefaultValues()
{
    ViewPropertiesMenu m;
    QVERIFY(m.menu());

    QVERIFY(m.showLayoutActions());
    QVERIFY(m.showLockAction());
    QVERIFY(m.showIconSizeActions());
    QVERIFY(!m.locked());
    QVERIFY(!m.sortDesc());
    QVERIFY(!m.sortDirsFirst());
}

void ViewPropertiesMenuTest::shouldNotCrashWithoutCheckedActions()
{
    // None of the action groups has a checked action until the configuration was applied, and
    // QML can read the properties before that. This used to dereference a null pointer.
    ViewPropertiesMenu m;
    QCOMPARE(m.arrangement(), 0);
    QCOMPARE(m.alignment(), 0);
    QCOMPARE(m.sortMode(), int(KDirModel::Name));
    QCOMPARE(m.iconSize(), 2);

    // Once a value was set, that is what is reported
    m.setArrangement(1);
    m.setAlignment(1);
    m.setSortMode(int(KDirModel::ModifiedTime));
    m.setIconSize(5);
    QCOMPARE(m.arrangement(), 1);
    QCOMPARE(m.alignment(), 1);
    QCOMPARE(m.sortMode(), int(KDirModel::ModifiedTime));
    QCOMPARE(m.iconSize(), 5);

    // Unsorted is a valid sort mode and is not the same as "nothing checked"
    m.setSortMode(-1);
    QCOMPARE(m.sortMode(), -1);
}

#include "moc_viewpropertiesmenutest.cpp"
