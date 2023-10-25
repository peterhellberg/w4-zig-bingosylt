all:
	zig build -Doptimize=ReleaseSmall

.PHONY: watch
watch:
	w4 watch

.PHONY: run
run:
	w4 run zig-out/lib/cart.wasm

.PHONY: clean
clean:
	rm -rf build
	rm -rf bundle

.PHONY: bundle
bundle: all
	@mkdir -p bundle
	# HTML
	w4 bundle zig-out/lib/cart.wasm --title Bingosylt --html bundle/bingosylt.html
	# Linux (ELF)
	w4 bundle zig-out/lib/cart.wasm --title Bingosylt --linux bundle/bingosylt.elf
	# Windows (PE32+)
	w4 bundle zig-out/lib/cart.wasm --title Bingosylt --windows bundle/bingosylt.exe

.PHONY: backup
backup: bundle
	cp bundle/bingosylt.* /run/user/1000/gvfs/afp-volume:host=diskstation.local,user=peter,volume=backups/Code/Bingosylt
