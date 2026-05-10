cmake_minimum_required(VERSION 3.22.1)
project(spectra_synth LANGUAGES CXX C)

# JUCE bootstrap (Java.java) calls System.loadLibrary("juce_jni"),
# so the native library MUST be named libjuce_jni.so.
set(LIB_NAME juce_jni)

set(VITAL_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../..)
set(JUCE_MODULES ${VITAL_ROOT}/third_party/JUCE/modules)
set(JUCE_LIB_CODE ${VITAL_ROOT}/standalone/JuceLibraryCode)
set(VITAL_SRC ${VITAL_ROOT}/src)

set(VITAL_DEFINES
    JUCE_ANDROID=1
    # juce_audio_devices.h silently undef's JUCE_USE_ANDROID_OBOE if
    # JUCE_ANDROID_API_VERSION < 16. Without this, Oboe.cpp doesn't get
    # included and juce_createRealtimeAudioThread is undefined at link.
    JUCE_ANDROID_API_VERSION=26
    JUCE_USE_ANDROID_OBOE=1
    JUCE_USE_OBOE_STABILIZED_CALLBACK=1
    JUCE_USE_ANDROID_OPENSLES=0
    JUCE_USE_CURL=0
    JUCE_LOAD_CURL_SYMBOLS_LAZILY=0
    JUCE_OPENGL_ES=1
    JUCE_ANDROID_GL_ES_VERSION_3_0=1
    JUCE_OPENGL3=1
    OPENGL_ES=1
    GL_GLEXT_PROTOTYPES=1
    NO_AUTH=1
    REQUIRE_AUTH=0
    JUCE_STANDALONE_APPLICATION=1
    JUCE_PUSH_NOTIFICATIONS=0
    JUCE_FIREBASE_ANALYTICS=0
    JUCE_DISPLAY_SPLASH_SCREEN=0
    JUCE_DSP_USE_SHARED_FFTW=0
    JUCE_DSP_USE_STATIC_FFTW=0
    JUCER_ANDROIDSTUDIO_SPECTRA_1=1
    JUCE_APP_VERSION=0.1.0
    JUCE_APP_VERSION_HEX=0x100
    JUCE_USE_DARK_SPLASH_SCREEN=1
)
# BUILD_DATE intentionally undefined here; getBuildTime() falls back to
# JUCE's compilation date when the macro is not 5 space-separated tokens.
# (CMake's target_compile_definitions can't pass a value with embedded
# spaces cleanly without losing it through later list expansions.)

set(VITAL_INCLUDES
    ${JUCE_LIB_CODE}
    ${JUCE_MODULES}
    ${VITAL_SRC}/common
    ${VITAL_SRC}/common/wavetable
    ${VITAL_SRC}/interface/editor_components
    ${VITAL_SRC}/interface/editor_sections
    ${VITAL_SRC}/interface/look_and_feel
    ${VITAL_SRC}/interface/wavetable
    ${VITAL_SRC}/interface/wavetable/editors
    ${VITAL_SRC}/interface/wavetable/overlays
    ${VITAL_SRC}/standalone
    ${VITAL_SRC}/synthesis/synth_engine
    ${VITAL_SRC}/synthesis/effects
    ${VITAL_SRC}/synthesis/filters
    ${VITAL_SRC}/synthesis/framework
    ${VITAL_SRC}/synthesis/lookups
    ${VITAL_SRC}/synthesis/modulators
    ${VITAL_SRC}/synthesis/modules
    ${VITAL_SRC}/synthesis/producers
    ${VITAL_SRC}/synthesis/utilities
    ${VITAL_ROOT}/third_party
)

# Vital uses unity-build cpp aggregates; reuse them.
set(VITAL_UNITY_SOURCES
    ${VITAL_SRC}/unity_build/common.cpp
    ${VITAL_SRC}/unity_build/synthesis.cpp
    ${VITAL_SRC}/unity_build/interface_editor_components.cpp
    ${VITAL_SRC}/unity_build/interface_editor_sections.cpp
    ${VITAL_SRC}/unity_build/interface_editor_sections2.cpp
    ${VITAL_SRC}/unity_build/interface_look_and_feel.cpp
    ${VITAL_SRC}/unity_build/interface_wavetable.cpp
    ${VITAL_SRC}/unity_build/standalone.cpp
)

# JUCE module unity-includes (only the .cpp variants, not .mm).
set(JUCE_UNITY_SOURCES
    ${JUCE_LIB_CODE}/include_juce_audio_basics.cpp
    ${JUCE_LIB_CODE}/include_juce_audio_devices.cpp
    ${JUCE_LIB_CODE}/include_juce_audio_formats.cpp
    ${JUCE_LIB_CODE}/include_juce_audio_processors.cpp
    ${JUCE_LIB_CODE}/include_juce_audio_utils.cpp
    ${JUCE_LIB_CODE}/include_juce_core.cpp
    ${JUCE_LIB_CODE}/include_juce_data_structures.cpp
    ${JUCE_LIB_CODE}/include_juce_dsp.cpp
    ${JUCE_LIB_CODE}/include_juce_events.cpp
    ${JUCE_LIB_CODE}/include_juce_graphics.cpp
    ${JUCE_LIB_CODE}/include_juce_gui_basics.cpp
    ${JUCE_LIB_CODE}/include_juce_gui_extra.cpp
    ${JUCE_LIB_CODE}/include_juce_opengl.cpp
    ${JUCE_LIB_CODE}/BinaryData.cpp
)

# NDK 26 ships cpu-features.h under sources/android/cpufeatures/ instead of
# the default sysroot include path. JUCE's juce_BasicNativeHeaders.h includes
# it unconditionally on Android, so we need both the header path and the .c
# file compiled into our lib.
set(ANDROID_CPUFEATURES_DIR ${ANDROID_NDK}/sources/android/cpufeatures)

add_library(${LIB_NAME} SHARED
    ${VITAL_UNITY_SOURCES}
    ${JUCE_UNITY_SOURCES}
    ${ANDROID_CPUFEATURES_DIR}/cpu-features.c
)

target_include_directories(${LIB_NAME} PRIVATE
    ${VITAL_INCLUDES}
    ${ANDROID_CPUFEATURES_DIR}
)
target_compile_definitions(${LIB_NAME} PRIVATE ${VITAL_DEFINES})

# Build Oboe (bundled inside JUCE) as a static library and link it in.
# Force STATIC so we don't ship a separate liboboe.so; Oboe's own CMakeLists
# uses an unspecified add_library() that follows BUILD_SHARED_LIBS.
set(OBOE_DIR ${JUCE_MODULES}/juce_audio_devices/native/oboe)
set(BUILD_SHARED_LIBS_SAVED ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS OFF CACHE INTERNAL "Force Oboe to build static")
add_subdirectory(${OBOE_DIR} oboe-build EXCLUDE_FROM_ALL)
set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_SAVED} CACHE INTERNAL "" FORCE)
target_include_directories(${LIB_NAME} PRIVATE ${OBOE_DIR}/include)

# Oboe's PolyphaseResampler{,Mono,Stereo}.cpp use assert() but rely on a
# transitive include that NDK 26's libc++ no longer provides. Force-include
# <cassert> for the whole oboe target so we don't have to modify vendored
# Oboe sources.
target_compile_options(oboe PRIVATE -include cassert)

# Find Android NDK libraries.
find_library(log-lib log)
find_library(android-lib android)
find_library(GLESv3-lib GLESv3)
find_library(EGL-lib EGL)
find_library(OpenSLES-lib OpenSLES)

target_link_libraries(${LIB_NAME}
    oboe
    ${log-lib}
    ${android-lib}
    ${GLESv3-lib}
    ${EGL-lib}
    ${OpenSLES-lib}
)

# Strip release builds for smaller APKs.
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(${LIB_NAME} PRIVATE -Os -flto)
    target_link_options(${LIB_NAME} PRIVATE -flto -Wl,--gc-sections,--exclude-libs,ALL)
endif()
