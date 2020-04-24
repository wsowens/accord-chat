default: web/chat.js

clean:
	rm -rf elm-stuff
	rm -rf web/*js
	rm -f chat.tar.gz

test:
	elm make src/Main.elm --output="web/chat.js"

web/chat.js:
	mkdir -p js && elm make src/Main.elm --output="web/chat.js" --optimize

release: web/chat.js
	./make_release.sh
