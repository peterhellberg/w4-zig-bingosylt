TITLE="BINGO! - Kodsnacks Spelsylt: 9"
NAME=w4-zig-bingosylt
ARCHIVE=${NAME}.zip
GAME_PATH=games/w4-zig-bingosylt/
GAME_URL=https://${HOSTNAME}/${GAME_PATH}
PUBLIC_PATH=~/public_html/${GAME_PATH}
HOSTNAME=peter.tilde.team

all:
	zig build

.PHONY: spy
spy:
	zig build spy

.PHONY: run
run:
	zig build run

.PHONY: clean
clean:
	rm -rf build
	rm -rf bundle

.PHONY: bundle
bundle: all
	@w4 bundle zig-out/bin/cart.wasm --title ${TITLE} --html bundle/${NAME}.html 		# HTML
	@w4 bundle zig-out/bin/cart.wasm --title ${TITLE} --linux bundle/${NAME}.elf 		# Linux (ELF)
	@w4 bundle zig-out/bin/cart.wasm --title ${TITLE} --windows bundle/${NAME}.exe 	# Windows (PE32+)
	@zip -juq bundle/${ARCHIVE} bundle/${NAME}.html bundle/${NAME}.elf bundle/${NAME}.exe
	@echo "✔ Updated bundle/${ARCHIVE}"

.PHONY: backup
backup: bundle
	cp bundle/${NAME}.* /run/user/1000/gvfs/afp-volume:host=diskstation.local,user=peter,volume=backups/Code/Bingosylt

.PHONY: deploy
deploy: bundle
	@scp -q bundle/${NAME}.html ${HOSTNAME}:${PUBLIC_PATH}/index.html
	@echo "✔ Updated ${NAME} on ${GAME_URL}"
	@scp -q bundle/${ARCHIVE} ${HOSTNAME}:${PUBLIC_PATH}${ARCHIVE}
	@echo "✔ Archive ${GAME_URL}${ARCHIVE}"
