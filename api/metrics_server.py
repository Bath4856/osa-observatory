"""
OSA Observatory -- Serveur interne metriques Prometheus
Sprint 19 -- api/metrics_server.py

Expose /metrics sur 0.0.0.0:9091 SANS authentification.
Accessible uniquement depuis le reseau Docker interne (osa-prometheus).
Jamais expose publiquement via Nginx.

Usage : lance en thread daemon depuis le lifespan FastAPI (main.py).
"""

import threading
import logging
from wsgiref.simple_server import make_server, WSGIRequestHandler
from prometheus_client import make_wsgi_app

log = logging.getLogger("osa_metrics_server")

class _SilentHandler(WSGIRequestHandler):
    """Supprime les logs de requete du serveur WSGI interne."""
    def log_message(self, format, *args):
        pass

def start_internal_metrics_server(host: str = "0.0.0.0", port: int = 9091) -> None:
    """
    Lance le serveur WSGI Prometheus sur host:port dans un thread daemon.
    A appeler au startup de l'application FastAPI.
    """
    metrics_app = make_wsgi_app()
    server = make_server(host, port, metrics_app, handler_class=_SilentHandler)
    thread = threading.Thread(
        target=server.serve_forever,
        name="osa-metrics-internal",
        daemon=True,
    )
    thread.start()
    log.info("Serveur metriques interne demarre sur %s:%d", host, port)
