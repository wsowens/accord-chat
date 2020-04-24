#!/bin/sh

mkdir -p chat

# minify the CSS
echo "Minifying CSS..."
curl -X POST -s --data-urlencode 'input@web/chat.css' https://cssminifier.com/raw \
 > chat/chat.min.css

# minify/uglify the JS
echo "Uglifying JS..."
uglifyjs web/chat.js > chat/chat.min.js

# update html to use minified css / js, remove ES6 style functions, then uglify it
echo "Minifying HTML..."
sed -e 's/chat.css/chat.min.css/g;
        s/chat.js/chat.min.js/g;
        s/\(([a-zA-Z0-9]\+)\) =>/function \1/g' web/index.html \
| html-minifier --collapse-whitespace --remove-comments --remove-optional-tags \
 --remove-redundant-attributes --remove-script-type-attributes \
 --remove-tag-whitespace --use-short-doctype \
 --minify-css true --minify-js true > chat/index.html

# create a tarball with the client and server files
echo "Creating archive..."
tar -cvzf chat.tar.gz chat/index.html chat/chat.min.css chat/chat.min.js server.py

echo "Done!"
