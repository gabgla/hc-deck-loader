VERSION=$(jq -r .version meta.json)
DIST_OBJ_PATH=./dist/HC_Deck_Loader_v$VERSION.json

mkdir dist 2> /dev/null
python3 generate_code.py > ./dist/main.lua

NEW_SCRIPT=$(<./dist/main.lua)

cp ./src/HC_Deck_Loader_Template.json ${DIST_OBJ_PATH}.tmp
# sed -i "s/<<LUASCRIPT>>/$(jq -R -s '.' < ./dist/main.lua)/g" $DIST_OBJ_PATH
jq '.ObjectStates[0].LuaScript = $newscript' --rawfile newscript ./dist/main.lua $DIST_OBJ_PATH.tmp > $DIST_OBJ_PATH
rm $DIST_OBJ_PATH.tmp