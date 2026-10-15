# SPDX-FileCopyrightText: 2025 WackyIdeas <wackyideas@disroot.org>
# SPDX-License-Identifier: BSD-3-Clause
configure_file(config.h.cmake config.h)

kauth_install_actions(io.gitgud.wackyideas.ootb kauth.actions)

ecm_setup_version(${PROJECT_VERSION}
    VARIABLE_PREFIX ATPOOTB
    VERSION_HEADER "${CMAKE_CURRENT_BINARY_DIR}/src/version-atpootb.h"
)
configure_file(config.h.cmake src/config.h)

add_executable(atpootbcursor_authhelper src/ootbauthhelper.cpp src/ootbauthhelper.h)
target_link_libraries(atpootbcursor_authhelper KF6::AuthCore KF6::ConfigCore KF6::I18n Qt6::DBus Qt6::Core)

install(TARGETS atpootbcursor_authhelper DESTINATION ${KAUTH_HELPER_INSTALL_DIR})
kauth_install_helper_files(atpootbcursor_authhelper io.gitgud.wackyideas.ootb root)

add_subdirectory(src)
