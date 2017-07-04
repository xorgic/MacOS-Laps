build:
	mkdir src build
	cp laps.sh src/laps
	cp com.github.xorgic.macoslaps.plist src/
	pkgbuild --root ./src --scripts ./scripts --identifier com.github.xorgic.macoslaps --version 1 --install-location /tmp ./build/MacOS-Laps.pkg

clean:
	rm -rf src build
