configure_file(startatp-wayland.cmake ${CMAKE_CURRENT_BINARY_DIR}/startatp-wayland)
install(
        FILES
                ${CMAKE_CURRENT_BINARY_DIR}/startatp-wayland
        PERMISSIONS
                OWNER_EXECUTE GROUP_EXECUTE WORLD_EXECUTE OWNER_WRITE OWNER_READ GROUP_READ WORLD_READ
        DESTINATION
                ${CMAKE_INSTALL_FULL_BINDIR}
)

configure_file(aerothemeplasma.desktop.cmake ${CMAKE_CURRENT_BINARY_DIR}/aerothemeplasma.desktop)
install(
        FILES
                ${CMAKE_CURRENT_BINARY_DIR}/aerothemeplasma.desktop
        DESTINATION
                ${KDE_INSTALL_DATADIR}/wayland-sessions
)

