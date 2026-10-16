/* SPDX-License-Identifier: LGPL-2.0-or-later */
#include <QCoreApplication>
#include <QDragEnterEvent>
#include <QDragLeaveEvent>
#include <QDropEvent>
#include <QMimeData>
#include <QFile>
#include <QTemporaryDir>
#include <KConfigLoader>
#include <KConfigPropertyMap>
#include <KSharedConfig>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtQuickTest/quicktest.h>

// Send platform drag events to actual QQuickWindows. In particular, these
// carry MIME data with no QML source object, as a native cross-window drag can.
class NativeDrag : public QObject
{
    Q_OBJECT
public:
    Q_INVOKABLE int drop(QQuickItem *target, const QString &format, const QString &payload, const QString &sessionFormat = QString())
    {
        QMimeData mime;
        mime.setData(format, payload.toUtf8());
        if (!sessionFormat.isEmpty()) mime.setData(sessionFormat, payload.toUtf8());
        const QPointF position = target->mapToScene(QPointF(target->width() / 2, target->height() / 2));
        QDragEnterEvent enter(position.toPoint(), Qt::MoveAction, &mime, Qt::LeftButton, Qt::NoModifier);
        QCoreApplication::sendEvent(target->window(), &enter);
        if (!enter.isAccepted()) {
            QDragLeaveEvent leave;
            QCoreApplication::sendEvent(target->window(), &leave);
            return Qt::IgnoreAction;
        }
        QDropEvent event(position, Qt::MoveAction, &mime, Qt::LeftButton, Qt::NoModifier);
        QCoreApplication::sendEvent(target->window(), &event);
        const auto action = event.isAccepted() ? event.dropAction() : Qt::IgnoreAction;
        QDragLeaveEvent leave;
        QCoreApplication::sendEvent(target->window(), &leave);
        return action;
    }
};

// Use Plasma's actual XML schema and KConfigPropertyMap, then recreate them
// from disk to check persistence independently of the QML objects' lifetime.
class PersistentSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *configuration READ configuration NOTIFY configurationChanged)
public:
    QObject *configuration() const { return m_map; }
    Q_INVOKABLE void reset()
    {
        clear();
        QFile::remove(m_directory.filePath("trayrc"));
        reload();
    }
    Q_INVOKABLE void reload()
    {
        clear();
        QFile xml(QStringLiteral(TRAY_CONFIG_PATH));
        const auto config = KSharedConfig::openConfig(m_directory.filePath("trayrc"), KConfig::SimpleConfig);
        config->reparseConfiguration();
        m_loader = new KConfigLoader(config, &xml, this);
        m_map = new KConfigPropertyMap(m_loader, this);
        Q_EMIT configurationChanged();
    }
    ~PersistentSettings() override { clear(); }
Q_SIGNALS:
    void configurationChanged();
private:
    void clear()
    {
        delete m_map;
        m_map = nullptr;
        delete m_loader;
        m_loader = nullptr;
    }
    QTemporaryDir m_directory;
    KConfigLoader *m_loader = nullptr;
    KConfigPropertyMap *m_map = nullptr;
};

class Setup : public QObject
{
    Q_OBJECT
public slots:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->rootContext()->setContextProperty("nativeDrag", &m_drag);
        engine->rootContext()->setContextProperty("nativeSettings", &m_settings);
    }
private:
    NativeDrag m_drag;
    PersistentSettings m_settings;
};

QUICK_TEST_MAIN_WITH_SETUP(systemtray_drag, Setup)
#include "native-drag.moc"
