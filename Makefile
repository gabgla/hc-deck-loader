DATABASE_URL="https://raw.githubusercontent.com/bones-bones/hellfall/main/src/data/Hellscube-Database.json"

.PHONY: build
build:
	bash build.sh

.PHONY: update-json
update-json:
	curl -o ./tools/Hellscube-Database.json ${DATABASE_URL}

.PHONY: copy-to-tts-dir
copy-to-tts-dir:
	bash copy.sh
