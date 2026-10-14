#include <QGuiApplication>
#include <QDebug>
#include <KPluginFactory>
#include <KPluginMetaData>
#include <Plasma/Applet>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc != 2) return 2;
    const KPluginMetaData metadata(QString::fromLocal8Bit(argv[1]), KPluginMetaData::AllowEmptyMetaData);
    const auto result = KPluginFactory::instantiatePlugin<Plasma::Applet>(metadata);
    if (!result) { qCritical() << result.errorString; return 1; }
    auto *applet = result.plugin;
    const char *methods[] = {"getDominantColor(QVariant)", "isActiveWindow(int)",
        "getWindowAspectRatio(int)", "sendMouseEvent(QQuickItem*)", "setMouseGrab(bool,QWindow*)"};
    for (const char *method : methods) {
        if (applet->metaObject()->indexOfMethod(method) < 0) {
            qCritical() << "Missing native method" << method;
            delete applet;
            return 1;
        }
    }
    qInfo() << "Loaded" << applet->metaObject()->className() << "as Plasma::Applet; 5 native methods present";
    delete applet;
    return 0;
}
