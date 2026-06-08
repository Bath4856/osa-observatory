"""
OSA Observatory -- Serveur interne metriques Prometheus
Sprint 19 -- api/metrics_server.py
Expose /metrics sur 0.0.0.0:9091 SANS authentification.
Accessible uniquement depuis le reseau Docker interne (osa-prometheus).
Jamais expose publiquement via Nginx.
Guard : demarrage uniquement dans le processus maitre uvicorn (PID le plus bas).
Les workers secondaires skippent proprement et le loggent.
"""
import os
import threading
import logging
log = logging.getLogger("osa_metrics_server")

def start_internal_metrics_server(host: str = "0.0.0.0", port: int = 9091) -> None:
    """
    Lance le serveur WSGI Prometheus sur host:port dans un thread daemon.
    Guard : utilise un fichier lock /tmp/osa_metrics.lock pour garantir
    qu'un seul processus demarre le serveur, meme en mode multi-worker uvicorn.
    """
    from wsgiref.simple_server import make_server, WSGIRequestHandler
    from prometheus_client import make_wsgi_app

    lock_file = "/tmp/osa_metrics_9091.lock"

    # Verifier si un autre processus a deja pris le lock
    if os.path.exists(lock_file):
        try:
            with open(lock_file) as f:
                pid = int(f.read().strip())
            # Verifier que le processus est toujours vivant
            os.kill(pid, 0)
            log.info("Serveur metriques deja actif (PID %d) — worker PID %d skip", pid, os.getpid())
            return
        except (OSError, ValueError):
            # Processus mort — nettoyer le lock et continuer
            os.remove(lock_file)
            log.info("Lock orphelin supprime — demarrage serveur metriques PID %d", os.getpid())

    # Ecrire le lock avec notre PID
    with open(lock_file, "w") as f:
        f.write(str(os.getpid()))

    class _SilentHandler(WSGIRequestHandler):
        def log_message(self, format, *args):
            pass

    metrics_app = make_wsgi_app()
    server = make_server(host, port, metrics_app, handler_class=_SilentHandler)
    thread = threading.Thread(
        target=server.serve_forever,
        name="osa-metrics-internal",
        daemon=True,
    )
    thread.start()
    log.info("Serveur metriques interne demarre sur %s:%d (PID %d)", host, port, os.getpid())
