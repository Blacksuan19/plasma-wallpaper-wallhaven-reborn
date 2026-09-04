#include <QElapsedTimer>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QTemporaryDir>
#include <QThread>

#include <functional>
#include <iostream>
#include <memory>

namespace
{
std::unique_ptr<QObject> createClient(QQmlEngine &engine, const QString &qmlPath)
{
    QQmlComponent component(&engine, QUrl::fromLocalFile(qmlPath));
    if (component.status() != QQmlComponent::Ready) {
        for (const QQmlError &error : component.errors()) {
            std::cerr << error.toString().toStdString() << '\n';
        }
        return nullptr;
    }

    std::unique_ptr<QObject> object(component.create());
    if (!object) {
        for (const QQmlError &error : component.errors()) {
            std::cerr << error.toString().toStdString() << '\n';
        }
    }
    return object;
}

QVariant invoke(QObject *object, const char *method, const QVariantList &arguments = {})
{
    QVariant result;
    bool invoked = false;
    if (arguments.size() == 2) {
        invoked = QMetaObject::invokeMethod(object,
                                            method,
                                            Qt::DirectConnection,
                                            Q_RETURN_ARG(QVariant, result),
                                            Q_ARG(QVariant, arguments.at(0)),
                                            Q_ARG(QVariant, arguments.at(1)));
    } else if (arguments.size() == 1) {
        invoked = QMetaObject::invokeMethod(object,
                                            method,
                                            Qt::DirectConnection,
                                            Q_RETURN_ARG(QVariant, result),
                                            Q_ARG(QVariant, arguments.at(0)));
    } else {
        invoked = QMetaObject::invokeMethod(object, method, Qt::DirectConnection, Q_RETURN_ARG(QVariant, result));
    }

    if (!invoked) {
        std::cerr << "Failed to invoke " << method << '\n';
        return {};
    }
    return result;
}

bool waitUntil(QGuiApplication &application, const std::function<bool()> &condition, int timeoutMs = 3000)
{
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < timeoutMs) {
        application.processEvents();
        if (condition()) {
            return true;
        }
        QThread::msleep(10);
    }
    application.processEvents();
    return condition();
}

bool expect(bool condition, const char *message)
{
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
    }
    return condition;
}
}

int main(int argc, char *argv[])
{
    QGuiApplication application(argc, argv);
    if (argc != 2) {
        std::cerr << "Usage: multi_engine_sync /path/to/SyncEngineClient.qml\n";
        return 2;
    }

    QTemporaryDir storage;
    if (!storage.isValid()) {
        std::cerr << "Failed to create temporary LocalStorage directory\n";
        return 2;
    }

    QQmlEngine firstEngine;
    QQmlEngine secondEngine;
    firstEngine.setOfflineStoragePath(storage.path());
    secondEngine.setOfflineStoragePath(storage.path());

    auto first = createClient(firstEngine, QString::fromLocal8Bit(argv[1]));
    auto second = createClient(secondEngine, QString::fromLocal8Bit(argv[1]));
    if (!first || !second) {
        return 2;
    }

    const QString databaseName = QStringLiteral("multi-engine-sync-test");
    const QString groupId = QStringLiteral("plasma-shared-screen-group");
    bool passed = true;
    passed &= expect(invoke(first.get(), "initialize", {databaseName, groupId}).toBool(), "first engine did not initialize");
    passed &= expect(invoke(second.get(), "initialize", {databaseName, groupId}).toBool(), "second engine did not initialize");

    const bool firstStarted = invoke(first.get(), "requestSelection", {QStringLiteral("file:///first.jpg")}).toBool();
    const bool secondStarted = invoke(second.get(), "requestSelection", {QStringLiteral("file:///second.jpg")}).toBool();
    passed &= expect(firstStarted, "first engine did not claim the initial request");
    passed &= expect(!secondStarted, "second engine also claimed the initial request");

    passed &= expect(waitUntil(application, [&]() {
        invoke(first.get(), "poll");
        invoke(second.get(), "poll");
        return first->property("currentUrl").toString() == QStringLiteral("file:///first.jpg")
            && second->property("currentUrl").toString() == QStringLiteral("file:///first.jpg");
    }), "both engines did not receive the first shared selection");
    passed &= expect(first->property("producerCalls").toInt() == 1, "first selection was not produced exactly once");
    passed &= expect(second->property("producerCalls").toInt() == 0, "duplicate producer ran in the second engine");

    const bool manualRefreshStarted = invoke(second.get(), "requestSelection", {QStringLiteral("file:///manual-refresh.jpg")}).toBool();
    passed &= expect(manualRefreshStarted, "second engine did not claim the manual refresh");
    passed &= expect(waitUntil(application, [&]() {
        invoke(first.get(), "poll");
        invoke(second.get(), "poll");
        return first->property("currentUrl").toString() == QStringLiteral("file:///manual-refresh.jpg")
            && second->property("currentUrl").toString() == QStringLiteral("file:///manual-refresh.jpg");
    }), "manual refresh did not propagate to both engines");
    passed &= expect(second->property("producerCalls").toInt() == 1, "manual refresh was not produced exactly once");
    passed &= expect(first->property("errorText").toString().isEmpty() && second->property("errorText").toString().isEmpty(), "a QML coordinator error occurred");

    invoke(first.get(), "unregister");
    invoke(second.get(), "unregister");

    if (!passed) {
        return 1;
    }

    std::cout << "PASS: separate QQmlEngine instances coalesced requests and shared refreshes\n";
    return 0;
}
