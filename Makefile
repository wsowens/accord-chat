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

install:
	rm -rf server_env
	python3 -m venv server_env
	server_env/bin/python3 -m pip install -r requirements.txt

install-systemd:
	./make_service.sh