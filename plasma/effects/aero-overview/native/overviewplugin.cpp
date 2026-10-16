/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include <effect/effecthandler.h>
#include <effect/quickeffect.h>

#include <QCoreApplication>
#include <QDebug>
#include <QPointer>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <QTimer>
#include <QUrl>

// No replacement compositor, effect, shortcuts, or window-management logic.
// Only the existing overview's QML source changes; KWin owns the component.
class OverviewOverride : public QObject
{
    Q_OBJECT

public:
    explicit OverviewOverride(QObject *parent = nullptr) : QObject(parent)
    {
        m_timer.setInterval(1000);
        connect(&m_timer, &QTimer::timeout, this, &OverviewOverride::apply);
    }

    ~OverviewOverride() override
    {
        m_timer.stop();
        if (m_effect && m_effect->source() == m_source) {
            // setSource cannot be changed while running. Unloading a styling
            // script is an explicit request to close the overview and restore it.
            m_effect->setRunning(false);
            if (!m_originalSource.isEmpty()) {
                m_effect->setSource(m_originalSource);
            } else {
                m_effect->loadFromModule(QStringLiteral("org.kde.kwin.overview"),
                                         QStringLiteral("Main"));
            }
            qInfo() << "AeroOverview: restored stock overview";
        }
    }

    Q_INVOKABLE bool install(const QUrl &source)
    {
        if (QCoreApplication::applicationVersion() != QStringLiteral(AERO_KWIN_VERSION)) {
            qWarning() << "AeroOverview: not applying; rebuild for KWin"
                       << QCoreApplication::applicationVersion();
            return false;
        }
        if (!source.isLocalFile() || !KWin::effects) {
            qWarning() << "AeroOverview: local source or effects handler unavailable";
            return false;
        }
        m_source = source;
        m_timer.start();
        apply();
        return true;
    }

private:
    void apply()
    {
        if (!KWin::effects) {
            return;
        }
        auto *effect = qobject_cast<KWin::QuickSceneEffect *>(
            KWin::effects->findEffect(QStringLiteral("overview")));
        if (!effect || effect->isRunning() || effect->source() == m_source) {
            return;
        }

        // Compile before touching the stock delegate. A missing QML import or
        // syntax error leaves the original overview entirely intact.
        QQmlComponent check(KWin::effects->qmlEngine(), m_source,
                            QQmlComponent::PreferSynchronous);
        if (check.status() == QQmlComponent::Loading) {
            return; // retry after asynchronous imports finish
        }
        if (check.isError()) {
            qWarning().noquote() << "AeroOverview: keeping stock overview:" << check.errorString();
            m_timer.stop();
            return;
        }
        m_effect = effect;
        m_originalSource = effect->source();
        effect->setSource(m_source);
        qInfo() << "AeroOverview: applied local view" << m_source;
    }

    QTimer m_timer;
    QPointer<KWin::QuickSceneEffect> m_effect;
    QUrl m_source;
    QUrl m_originalSource;
};

class AeroOverviewPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<OverviewOverride>(uri, 1, 0, "OverviewOverride");
    }
};

#include "overviewplugin.moc"
