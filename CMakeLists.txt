cmake_minimum_required(VERSION 3.6)
project (vorlua C)
add_subdirectory (crpat)

find_package (Lua 5.2)
if (NOT LUA_FOUND)
find_package (Lua51 REQUIRED)
endif()

add_executable (vorlua vorlua.c)
target_include_directories (vorlua PRIVATE ${LUA_INCLUDE_DIR})
target_link_libraries(vorlua ${LUA_LIBRARIES} crpat)

