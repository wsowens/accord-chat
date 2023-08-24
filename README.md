# Accord - Chat for ~~Gamers~~ Honda Fans
A simple chatroom application, created in about 24 hours with Elm, WebSockets, and Python 3.

Deployed here: [https://chat.ovvens.com](https://chat.ovvens.com)

## Dependencies
To compile this project, you need Elm (0.19) and Python (>=3.7).
You can find instructions for installing Elm [here](https://guide.elm-lang.org/install/elm.html).
Additional Elm dependencies will be installed automatically (see `elm.json`).

The Python server code requires the `websockets` package, you can install with pip:
```sh
pip3 install websockets
```

### Optional Dependencies
`make release` requires `curl` (refer to your package manager), `uglifyjs`, and `html-minifier`.
The latter to programs can be installed via `npm`:

```sh
npm install -g uglify-js html-minifier
```

`make release` simply minifies the HTML, CSS, and JS.
This step is not required.

## Getting Started
After installing the dependencies above, you can compile the Elm module simply by calling `make`.
This will produce `web/chat.js`.

Next, serve the files in `web` using a server of your choice.
For simple testing, you can use python3's http.server:
```sh
python3 -m http.server --directory web 8000
```

In Firefox or Chrome, navigate http://localhost:8000, and you should see an error screen (since no websocket server is running).

To run the websocket server, simply run
```sh
python3 server.py
```

Now, navigate to http://localhost:8000 again, and you should see a prompt ("What should we call you?").

## Disclaimer
This program is largely just a proof-of-concept.
If you want to use it seriously, I strongly advise serving your HTML over with a more robust server using HTTPS.
When you switch to HTTPS, most browsers will no longer permit insecure WebSocket connection ("ws://hostname"), so you will have to switch to a secure connection ("wss://hostname") in `web/index.html`.

`server.py` does not include any built-in SSL support, you you can either [add this yourself](https://websockets.readthedocs.io/en/stable/howto/quickstart.html#encrypt-connections) or [use a reverse proxy](https://www.nginx.com/blog/websocket-nginx/). 

## License
This project is licensed under the Apache License. See [LICENSE](./LICENSE) for details.
