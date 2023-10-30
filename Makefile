NAME=bingosylt
TITLE="Bingosylt (Kodsnacks Tvåveckorssylt - \#9)"

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
	@scp -q bundle/${NAME}.html peter.tilde.team:~/public_html/games/w4-zig-bingosylt/index.html
	@echo "✔ Updated ${NAME} on https://peter.tilde.team/games/w4-zig-bingosylt/"
