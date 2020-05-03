INSTALL=$(pwd)/$(dirname $0)
REPORT="$1"
PASSWORD="$2"
LUA_PATH="$LUA_PATH;$INSTALL/?.lua;$INSTALL/lua/?.lua;$INSTALL/lua/?/init.lua"
$INSTALL/vorlua $INSTALL/vorlage.lua "$REPORT" "$PASSWORD"

