install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DESTINATION ${DFHACK_DATA_DESTINATION}
        FILES_MATCHING PATTERN "*.lua"
                       PATTERN "*.rb"
                       PATTERN "*.json"
                       PATTERN "3rdparty" EXCLUDE
)
