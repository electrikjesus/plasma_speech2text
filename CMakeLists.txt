cmake_minimum_required(VERSION 3.16)
project(plasma-s2t VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(Qt5 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(KF5Plasma REQUIRED)
find_package(KF5GlobalAccel REQUIRED)
find_package(KF5I18n REQUIRED)

# Optional Vosk STT support
find_package(PkgConfig)
if(PKG_CONFIG_FOUND)
    pkg_check_modules(VOSK vosk)
    if(VOSK_FOUND)
        add_definitions(-DUSE_VOSK)
        include_directories(${VOSK_INCLUDE_DIRS})
        link_directories(${VOSK_LIBRARY_DIRS})
    endif()
endif()

include(FeatureSummary)
feature_summary(WHAT ALL)

add_library(s2t MODULE s2t.cpp vosk-stt.cpp)

target_link_libraries(s2t
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
    KF5::Plasma
    KF5::GlobalAccel
    KF5::I18n
)

if(VOSK_FOUND)
    target_link_libraries(s2t ${VOSK_LIBRARIES})
endif()

install(TARGETS s2t
    LIBRARY DESTINATION ${KDE_INSTALL_PLUGINDIR}/plasma/applets/s2t
)

install(FILES metadata.json
    DESTINATION ${KDE_INSTALL_DATADIR}/plasma/applets/s2t
)

install(DIRECTORY contents
    DESTINATION ${KDE_INSTALL_DATADIR}/plasma/applets/s2t
)
