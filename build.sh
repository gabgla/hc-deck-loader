VERSION=$(jq -r .version meta.json)
SCRIPT_PATH=./dist/main.lua
DIST_OBJ_PATH=./dist/HC_Deck_Loader_v$VERSION.json

mkdir dist 2> /dev/null
python3 generate_code.py > $SCRIPT_PATH

cp ./src/HC_Deck_Loader_Template.json ${DIST_OBJ_PATH}.tmp
jq '.ObjectStates[0].LuaScript = $newscript' --rawfile newscript $SCRIPT_PATH $DIST_OBJ_PATH.tmp > $DIST_OBJ_PATH
rm $DIST_OBJ_PATH.tmp
