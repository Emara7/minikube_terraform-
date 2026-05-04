import logging
import os
import random
import time
from http import HTTPStatus

from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()


class TraceIdFilter(logging.Filter):
    def filter(self, record):
        if not hasattr(record, "trace_id"):
            record.trace_id = "none"
        return True


logging.basicConfig(
    level=LOG_LEVEL,
    format='%(asctime)s %(levelname)s service=cloud-native-demo trace_id=%(trace_id)s message="%(message)s"',
)
for handler in logging.getLogger().handlers:
    handler.addFilter(TraceIdFilter())
logger = logging.getLogger(__name__)

app = Flask(__name__)
REQUEST_COUNT = Counter(
    "app_http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "app_http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5),
)


def _route_label() -> str:
    return request.url_rule.rule if request.url_rule else request.path


@app.before_request
def start_timer():
    request.start_time = time.perf_counter()


@app.after_request
def record_metrics(response):
    endpoint = _route_label()
    latency = time.perf_counter() - getattr(request, "start_time", time.perf_counter())
    REQUEST_LATENCY.labels(request.method, endpoint).observe(latency)
    REQUEST_COUNT.labels(request.method, endpoint, response.status_code).inc()
    logger.info(
        "request completed",
        extra={"trace_id": request.headers.get("X-Request-ID", "none")},
    )
    return response


@app.get("/health")
def health():
    return jsonify(status="ok", service="cloud-native-demo"), HTTPStatus.OK


@app.get("/api")
def api():
    simulated_latency = float(os.getenv("SIMULATED_LATENCY_SECONDS", "0"))
    error_rate = float(os.getenv("SIMULATED_ERROR_RATE", "0"))
    if simulated_latency > 0:
        time.sleep(simulated_latency)
    if error_rate > 0 and random.random() < error_rate:
        return jsonify(error="simulated failure"), HTTPStatus.INTERNAL_SERVER_ERROR
    return jsonify(message="hello from the cloud-native demo", version=os.getenv("APP_VERSION", "dev"))


@app.get("/metrics")
def metrics():
    return generate_latest(), HTTPStatus.OK, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
