/*
    SPDX-FileCopyrightText: 2021  <>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "SevenStart.h"

#include <QFileInfo>

SevenStart::SevenStart(QObject *parentObject, const KPluginMetaData &data, const QVariantList &args)
    : Plasma::Applet(parentObject, data, args)
{
}

SevenStart::~SevenStart()
{
}

bool SevenStart::fileExists(QUrl path)
{
    if(!path.isLocalFile()) return false;

    QFileInfo file(path.toLocalFile());
    return file.exists() && file.isFile();
}

K_PLUGIN_CLASS(SevenStart)

#include "SevenStart.moc"
