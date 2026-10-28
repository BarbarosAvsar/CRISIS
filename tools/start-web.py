"""Serve the static website without npm or administrator privileges."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import threading
import webbrowser


def main():
    root = Path(__file__).resolve().parents[1] / "web"
    if not (root / "index.html").is_file():
        print("Der web-Ordner fehlt. Bitte das gesamte Projekt zuerst entpacken.")
        return 1
    handler = partial(SimpleHTTPRequestHandler, directory=str(root))
    try:
        server = ThreadingHTTPServer(("127.0.0.1", 4173), handler)
    except OSError as error:
        print("Port 4173 konnte nicht geoeffnet werden: " + str(error))
        print("Schliessen Sie einen bereits laufenden CRISIS-Server und versuchen Sie es erneut.")
        return 1
    print("CRISIS: http://127.0.0.1:4173")
    print("Der historische Datenbestand funktioniert ohne Internet.")
    print("Neue Marktdaten abrufen: mit Node.js 22+ und START-WEB.cmd starten.")
    print("Dieses Fenster offen lassen; Strg+C beendet den Server.")
    opener = threading.Timer(0.4, webbrowser.open, args=("http://127.0.0.1:4173",))
    opener.daemon = True
    opener.start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
