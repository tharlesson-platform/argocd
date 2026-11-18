# Base pública gratuita fixada; nenhum componente AWS é necessário.
FROM cgr.dev/chainguard/wolfi-base@sha256:e9b8c3739e5fb5fc778843a2ce74f8620588c9ddc9c44918cead527abcb0b628 AS python-base
RUN apk upgrade --no-cache && apk add --no-cache 'python-3.12>=3.12.15-r2' ca-certificates

FROM python-base AS builder
RUN python3.12 -m venv /opt/venv && /opt/venv/bin/python -m pip install --no-cache-dir pip==26.3
COPY requirements-runtime.txt /tmp/requirements-runtime.txt
RUN /opt/venv/bin/python -m pip install --no-cache-dir -r /tmp/requirements-runtime.txt \
    && /opt/venv/bin/python -m pip check \
    && /opt/venv/bin/python -m pip uninstall -y pip

FROM python-base AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PATH=/opt/venv/bin:$PATH
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY main.py .
RUN find /usr/share/python-wheels -maxdepth 1 -type f -name 'pip-*.whl' -delete
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3)"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
