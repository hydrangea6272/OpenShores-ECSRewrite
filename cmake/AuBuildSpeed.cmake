# Build-speed options. Every option can be turned off to get the old build back.
#
#   AU_PCH            Precompile Qt and std headers for each code target (ON).
#   AU_UNITY_BUILD    Compile sources in batches of AU_UNITY_BATCH_SIZE (OFF).
#   AU_LINKER         Linker to use: auto, default, mold, lld or gold (auto).
#   AU_CCACHE         Use ccache when no compiler launcher is set (ON).
#   AU_AUTOGEN_PARALLEL  Don't make each library's moc wait for its deps (ON).

option(AU_PCH "Precompile Qt and standard headers" ON)
option(AU_UNITY_BUILD "Compile sources in unity batches" OFF)
set(AU_UNITY_BATCH_SIZE 8 CACHE STRING "Source files per unity batch")
set(AU_LINKER auto CACHE STRING "Linker: auto, default, mold, lld or gold")
set_property(CACHE AU_LINKER PROPERTY STRINGS auto default mold lld gold)
option(AU_CCACHE "Use ccache when it is installed and no launcher is set" ON)
option(AU_AUTOGEN_PARALLEL "Let each target's moc run without waiting for its dependencies to build" ON)

# --- Library parallelism ----------------------------------------------------
# By default CMake makes each target's AUTOMOC step wait until every library it
# links against is fully built. Because every object waits on its target's moc
# step, the libraries compiled one after another (AuUtil -> ... -> AuAtom ->
# AuClient -> AuDesigner), leaving cores idle while each library's few huge
# files finished. Nothing moc generates here depends on another library's
# build outputs, so the wait isn't needed.
if(AU_AUTOGEN_PARALLEL)
    set(CMAKE_AUTOGEN_ORIGIN_DEPENDS OFF)
endif()

# --- ccache -----------------------------------------------------------------
if(AU_CCACHE AND NOT CMAKE_CXX_COMPILER_LAUNCHER)
    find_program(AU_CCACHE_PROGRAM ccache)
    if(AU_CCACHE_PROGRAM)
        set(CMAKE_CXX_COMPILER_LAUNCHER "${AU_CCACHE_PROGRAM}")
        message(STATUS "Build speed: ccache ${AU_CCACHE_PROGRAM}")
    endif()
endif()

# ccache only reuses results for TUs built with a precompiled header when its
# sloppiness allows it (see the CCACHE_SLOPPINESS setting in the Docker build
# scripts) and, with GCC, when -fpch-preprocess is passed.
# -Winvalid-pch reports any file the precompiled header couldn't be used for.
set(AU_PCH_FLAGS)
if(AU_PCH AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(AU_PCH_FLAGS -fpch-preprocess -Winvalid-pch)
endif()

# --- Linker -----------------------------------------------------------------
# Linking the clients pulls in several very large static libraries, which the
# default GNU ld handles slowly. mold and lld are much faster drop-ins.
set(AU_LINKER_FLAG)
if(NOT AU_LINKER STREQUAL "default" AND NOT MSVC AND NOT APPLE AND NOT MINGW)
    set(candidates)
    if(AU_LINKER STREQUAL "auto")
        set(candidates mold lld)
    else()
        set(candidates ${AU_LINKER})
    endif()
    include(CheckCXXSourceCompiles)
    foreach(linker IN LISTS candidates)
        set(CMAKE_REQUIRED_LINK_OPTIONS "-fuse-ld=${linker}")
        set(CMAKE_REQUIRED_QUIET ON)
        check_cxx_source_compiles("int main() { return 0; }" AU_HAVE_LINKER_${linker})
        unset(CMAKE_REQUIRED_LINK_OPTIONS)
        unset(CMAKE_REQUIRED_QUIET)
        if(AU_HAVE_LINKER_${linker})
            set(AU_LINKER_FLAG "-fuse-ld=${linker}")
            message(STATUS "Build speed: linking with ${linker}")
            break()
        endif()
    endforeach()
    if(NOT AU_LINKER_FLAG AND NOT AU_LINKER STREQUAL "auto")
        message(FATAL_ERROR "AU_LINKER=${AU_LINKER} was requested but does not work with this compiler")
    endif()
endif()

# Sources that can't share a unity batch, compiled on their own instead. Each
# defines a file-scope static, class or typedef with the same name as another
# file in its target, or #defines a macro that another file or a header
# defines differently.
# Regenerate with: python3 tools/unity-scan.py   (--why shows the names)
set(AU_UNITY_EXCLUDE
    src/lib/atom/entities/celestial/daasteroid.cpp
    src/lib/atom/entities/celestial/daworldgasgiant.cpp
    src/lib/atom/entities/celestial/daworldglobe.cpp
    src/lib/atom/entities/celestial/daworldll.cpp
    src/lib/atom/entities/celestial/daworldringsection.cpp
    src/lib/atom/entities/structures/daarena.cpp
    src/lib/atom/entities/structures/dabd.cpp
    src/lib/atom/entities/units/daunit.cpp
    src/lib/atom/entities/vehicles/dasc.cpp
    src/lib/atom/entities/vehicles/davessel.cpp
    src/lib/atom/parts/dpstationsensor.cpp
    src/lib/atom/parts/dpstationtransporter.cpp
    src/lib/atom/parts/dpstationweapon.cpp
    src/lib/atom/ui/audnaview.cpp
    src/lib/atom/ui/auitemview.cpp
    src/lib/client/economy/AuSendFunds.cpp
    src/lib/client/economy/augadeposit.cpp
    src/lib/client/economy/augawithdraw.cpp
    src/lib/client/navigation/aulocatorstarmap.cpp
    src/lib/client/navigation/austarmapwidget.cpp
    src/lib/data/designs/aubdreport.cpp
    src/lib/data/designs/auscreport.cpp
    src/lib/data/economy/deconstructionprocess.cpp
    src/lib/data/reports/auitreport.cpp
    src/lib/designer/core/audesignerview.cpp
    src/lib/designer/core/dtgl.cpp
    src/lib/designer/spacecraft/appearance/ausceffectcylindricaldlg.cpp
    src/lib/designer/spacecraft/appearance/ausceffectprojectdlg.cpp
    src/lib/designer/spacecraft/appearance/ausceffectsphericaldlg.cpp
    src/lib/designer/spacecraft/appearance/ausceffectunwrapdlg.cpp
    src/lib/designer/spacecraft/appearance/auscpalettedlg.cpp
    src/lib/designer/spacecraft/appearance/ausctexturecylindricaldlg.cpp
    src/lib/designer/spacecraft/appearance/ausctextureprojectdlg.cpp
    src/lib/designer/spacecraft/appearance/ausctexturesphericaldlg.cpp
    src/lib/designer/spacecraft/appearance/ausctextureunwrapdlg.cpp
)

if(AU_PCH)
    message(STATUS "Build speed: precompiled headers on")
endif()
if(AU_UNITY_BUILD)
    message(STATUS "Build speed: unity builds on (batch size ${AU_UNITY_BATCH_SIZE})")
endif()

# Applied by au_configure_target to every code target. Resource shards (only
# generated Qt resource data) skip the precompiled header since they don't use it.
function(au_apply_build_speed target directory)
    if(AU_LINKER_FLAG)
        get_target_property(type ${target} TYPE)
        if(type STREQUAL "EXECUTABLE" OR type STREQUAL "SHARED_LIBRARY")
            target_link_options(${target} PRIVATE ${AU_LINKER_FLAG})
        endif()
    endif()

    file(RELATIVE_PATH relative "${CMAKE_SOURCE_DIR}" "${directory}")
    if(relative MATCHES "^resources/")
        return()
    endif()

    if(AU_PCH)
        # Every target reuses one precompiled header instead of building its
        # own (~200 MB each with GCC). That is valid because the per-library
        # -D flags don't appear in any header it contains.
        if(NOT TARGET AuPch)
            add_library(AuPch STATIC "${CMAKE_SOURCE_DIR}/cmake/AuPch.cpp")
            target_link_libraries(AuPch PRIVATE AuBuildSettings AuQt)
            target_precompile_headers(AuPch PRIVATE
                "$<$<COMPILE_LANGUAGE:CXX>:${CMAKE_SOURCE_DIR}/cmake/AuPrecompiled.h>"
            )
            target_compile_options(AuPch PRIVATE ${AU_PCH_FLAGS})
        endif()
        target_precompile_headers(${target} REUSE_FROM AuPch)
        target_compile_options(${target} PRIVATE ${AU_PCH_FLAGS})
    endif()

    if(AU_UNITY_BUILD)
        set_target_properties(${target} PROPERTIES
            UNITY_BUILD ON
            UNITY_BUILD_BATCH_SIZE ${AU_UNITY_BATCH_SIZE}
        )
        get_target_property(sources ${target} SOURCES)
        foreach(source IN LISTS sources)
            file(RELATIVE_PATH source_relative "${CMAKE_SOURCE_DIR}" "${source}")
            if(source_relative IN_LIST AU_UNITY_EXCLUDE)
                set_source_files_properties("${source}" PROPERTIES
                    SKIP_UNITY_BUILD_INCLUSION ON
                )
            endif()
        endforeach()
    endif()
endfunction()
