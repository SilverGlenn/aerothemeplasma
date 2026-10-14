cmake_minimum_required(VERSION 3.16)
project(win7_taskbar_preview LANGUAGES CXX)
# Staging-only build: compile the upstream native applet without behavioral edits.
set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6I18n REQUIRED)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6Svg REQUIRED)
find_package(KF6Config REQUIRED)
find_package(Plasma REQUIRED)
find_package(PlasmaQuick REQUIRED)
set(native "${CMAKE_CURRENT_SOURCE_DIR}/../../plasma/plasmoids/src/seventasks_src/src")
add_library(win7_preview MODULE "${native}/seventasks.cpp" "${native}/seventasks.h")
set_target_properties(win7_preview PROPERTIES
    OUTPUT_NAME "local.win7.seventasks.preview"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins/plasma/applets")
target_compile_definitions(win7_preview PRIVATE TRANSLATION_DOMAIN="plasma_applet_io.gitgud.wackyideas.seventasks")
target_link_libraries(win7_preview PRIVATE Qt6::Gui Qt6::Quick KF6::I18n KF6::WindowSystem
    Plasma::Plasma Plasma::PlasmaQuick KF6::Svg KF6::ConfigCore KF6::ConfigGui KF6::CoreAddons)
add_executable(preview-native-check "${CMAKE_CURRENT_SOURCE_DIR}/../../tests/taskbar/preview-native-check.cpp")
target_link_libraries(preview-native-check PRIVATE Qt6::Gui Qt6::Quick Plasma::Plasma KF6::CoreAddons)
# Intentionally no install() rule: nothing is placed on the live desktop.
