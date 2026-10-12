/*
    SPDX-FileCopyrightText: 2021  <>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef SEVENSTART_H
#define SEVENSTART_H

#include <QUrl>
#include <QVariant>
#include <QVariantList>

#include <Plasma/Applet>

class SevenStart : public Plasma::Applet
{
    Q_OBJECT

public:
    SevenStart(QObject *parentObject, const KPluginMetaData &data, const QVariantList &args);
    ~SevenStart();

    Q_INVOKABLE bool fileExists(QUrl path);
};

#endif
