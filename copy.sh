if [[ -z "${TTS_SAVED_OBJECTS_PATH}" ]]; then
    >&2 echo "TTS_SAVED_OBJECTS_PATH variable is not set"    
else
    cp ./dist/*.json ${TTS_SAVED_OBJECTS_PATH}
fi
