NAME=bingosylt
TITLE="Bingosylt (Kodsnacks Tvåveckorssylt - \#9)"
HOSTNAME=peter.tilde.team
GAME_PATH=games/w4-zig-bingosylt/
PUBLIC_PATH=~/public_html/${GAME_PATH}
ARCHIVE=w4-zig-bingosylt-itch.zip
GAME_URL=https://${HOSTNAME}/${GAME_PATH}

all:
	zig build -Doptimize=ReleaseSmall

.PHONY: spy
spy:
	spy --inc src -q clear-zig build -Doptimize=ReleaseSmall

.PHONY: run
run:
	w4 run --no-open --no-qr zig-out/lib/cart.wasm

.PHONY: clean
clean:
	rm -rf build
	rm -rf bundle

.PHONY: bundle
bundle: all
	@mkdir -p bundle
	@w4 bundle zig-out/lib/cart.wasm --title ${TITLE} --html bundle/${NAME}.html 		# HTML
	@w4 bundle zig-out/lib/cart.wasm --title ${TITLE} --linux bundle/${NAME}.elf 		# Linux (ELF)
	@w4 bundle zig-out/lib/cart.wasm --title ${TITLE} --windows bundle/${NAME}.exe 	# Windows (PE32+)

.PHONY: backup
backup: bundle
	cp bundle/${NAME}.* /run/user/1000/gvfs/afp-volume:host=diskstation.local,user=peter,volume=backups/Code/Bingosylt

.PHONY: deploy
deploy: bundle
	@scp -q bundle/${NAME}.html ${HOSTNAME}:${PUBLIC_PATH}/index.html
	@echo "✔ Updated ${NAME} on ${GAME_URL}"
	@ssh ${HOSTNAME} 'zip -juq ${PUBLIC_PATH}${ARCHIVE} ${PUBLIC_PATH}index.html'
	@echo "✔ Updated Itch .zip on ${GAME_URL}${ARCHIVE}"
