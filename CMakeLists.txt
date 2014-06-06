# Copyright (C) 2014 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

# C type needed for correct library suffix and prefix detection
project ( luadist-git NONE )
cmake_minimum_required ( VERSION 2.8 )
include ( cmake/dist.cmake )
include ( lua )

## LuaDist settings
# Host specific setup
set ( DETECTED_TYPE ${CMAKE_SYSTEM_PROCESSOR} )
set ( DETECTED_ARCH ${CMAKE_SYSTEM_NAME} )

if ( CYGWIN )
  # Make sure Cygwin uses correct arch and type.
  set ( DETECTED_TYPE x86 )
  set ( DETECTED_ARCH Cygwin )
elseif ( MSVC )
  set ( DETECTED_TYPE MSVC32 )
endif ( )

if ( DETECTED_ARCH STREQUAL "Darwin" )
  # Mac keeps CMAKE_SYSTEM_PROCESSOR set to i386 even on 64bit systems
  execute_process ( COMMAND uname -m OUTPUT_VARIABLE DETECTED_TYPE OUTPUT_STRIP_TRAILING_WHITESPACE )
endif ( )

if ( DETECTED_ARCH STREQUAL "Linux" )
  message( "DETECTING ...")
  # Determine LINUX flavour using lsb_release
  execute_process ( COMMAND lsb_release -is OUTPUT_VARIABLE DETECTED_ARCH OUTPUT_STRIP_TRAILING_WHITESPACE )
endif ()

set ( DIST_TYPE ${DETECTED_TYPE} CACHE STRING "Host system type. PLEASE CHECK!" )
set ( DIST_ARCH ${DETECTED_ARCH} CACHE STRING "Host system architecture. PLEASE CHECK!" )
message( "Detected system: ${DETECTED_ARCH}-${DETECTED_TYPE}" )
message( "Configured system: ${DIST_ARCH}-${DIST_TYPE}")

configure_file ( dist/config.lua.in ${CMAKE_CURRENT_BINARY_DIR}/dist/config.lua @ONLY )

# Install files
install_lua_executable ( luadist luadist.lua )
install_lua_module ( dist.config ${CMAKE_CURRENT_BINARY_DIR}/dist/config.lua )
install_lua_module ( dist.constraints dist/constraints.lua )
install_lua_module ( dist.depends dist/depends.lua )
install_lua_module ( dist.git dist/git.lua )
install_lua_module ( dist.init dist/init.lua )
install_lua_module ( dist.manifest dist/manifest.lua )
install_lua_module ( dist.package dist/package.lua )
install_lua_module ( dist.sys dist/sys.lua )
install_lua_module ( dist.utils dist/utils.lua )

install_data ( COPYRIGHT.TXT )
install_data ( README.md )
install_test ( test/ )

# Tests
add_lua_test ( test/test_depends.lua )
