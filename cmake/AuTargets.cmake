include(CMakeParseArguments)

function(au_collect_sources output directory)
    file(GLOB_RECURSE sources CONFIGURE_DEPENDS
        "${directory}/*.cpp"
        "${directory}/*.h"
        "${directory}/*.qrc"
    )

    if(WIN32)
        file(GLOB_RECURSE windows_resources CONFIGURE_DEPENDS
            "${directory}/*.rc"
        )
        list(APPEND sources ${windows_resources})
    endif()

    if(NOT sources)
        message(FATAL_ERROR "No sources found for ${directory}")
    endif()

    set(${output} ${sources} PARENT_SCOPE)
endfunction()

function(au_collect_include_directories output directory)
    file(GLOB_RECURSE headers CONFIGURE_DEPENDS "${directory}/*.h")
    set(include_directories "${directory}")
    foreach(header IN LISTS headers)
        get_filename_component(header_directory "${header}" DIRECTORY)
        list(APPEND include_directories "${header_directory}")
    endforeach()
    list(REMOVE_DUPLICATES include_directories)
    set(${output} ${include_directories} PARENT_SCOPE)
endfunction()

function(au_configure_target target directory)
    au_collect_include_directories(include_directories "${directory}")
    target_link_libraries(${target} PUBLIC AuBuildSettings AuQt)
    target_include_directories(${target} PUBLIC ${include_directories})
    au_apply_build_speed(${target} "${directory}")
endfunction()

function(au_add_static_library target directory)
    set(options)
    set(one_value_args DEFINE)
    cmake_parse_arguments(ARG "${options}" "${one_value_args}" "" ${ARGN})

    au_collect_sources(sources "${directory}")
    add_library(${target} STATIC ${sources})
    au_configure_target(${target} "${directory}")

    if(ARG_DEFINE)
        target_compile_definitions(${target} PRIVATE ${ARG_DEFINE})
    endif()
endfunction()

function(au_add_shared_library target directory)
    set(options)
    set(one_value_args DEFINE)
    cmake_parse_arguments(ARG "${options}" "${one_value_args}" "" ${ARGN})

    au_collect_sources(sources "${directory}")
    add_library(${target} SHARED ${sources})
    au_configure_target(${target} "${directory}")
    set_target_properties(${target} PROPERTIES
        VERSION "${PROJECT_VERSION}"
        SOVERSION "${PROJECT_VERSION_MAJOR}"
    )

    if(ARG_DEFINE)
        target_compile_definitions(${target} PRIVATE ${ARG_DEFINE})
    endif()
endfunction()

function(au_add_executable target directory)
    au_collect_sources(sources "${directory}")
    add_executable(${target} ${sources})
    au_configure_target(${target} "${directory}")
    target_link_libraries(${target} PRIVATE AuPlatform)
endfunction()
