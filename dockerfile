# =========================
# Build stage
# =========================
FROM python:3.11-slim AS build
WORKDIR /app

# System deps + Node 18 + mysqlclient build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git \
    build-essential pkg-config \
    default-libmysqlclient-dev \
  && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# Copy repo
COPY . .

# ---------- Frontend deps (NO build here) ----------
WORKDIR /app/next
RUN npm ci

# ---------- Backend deps ----------
WORKDIR /app/platform
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip

# Install backend requirements (requirements.txt or pyproject.toml)
RUN if [ -f requirements.txt ]; then pip install -r requirements.txt; \
    elif [ -f pyproject.toml ]; then pip install .; \
    else echo "No requirements.txt or pyproject.toml in /platform" && exit 1; fi


# =========================
# Runtime stage
# =========================
FROM python:3.11-slim
WORKDIR /app

# Runtime deps + Node 18 + supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates supervisor \
  && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# Copy app + venv from build stage
COPY --from=build /app /app
COPY --from=build /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Supervisor config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 3000
CMD ["/usr/bin/supervisord","-n"]
