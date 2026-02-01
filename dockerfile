# =========================
# BUILD STAGE
# =========================
FROM python:3.11-slim AS build

# System deps (node, build tools, mysqlclient deps)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git \
    build-essential pkg-config \
    default-libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# ---- Build NextJS ----
WORKDIR /app/next

# Provide BUILD-TIME placeholders (only to satisfy env validation during build)
# These do NOT replace runtime env vars on Render.
ARG DATABASE_URL="postgresql://user:pass@localhost:5432/db?schema=public"
ARG NEXTAUTH_SECRET="build-time-placeholder-secret"
ARG NEXTAUTH_URL="http://localhost:3000"

ENV DATABASE_URL=$DATABASE_URL \
    NEXTAUTH_SECRET=$NEXTAUTH_SECRET \
    NEXTAUTH_URL=$NEXTAUTH_URL \
    NODE_ENV=production

RUN npm ci
RUN npm run build

# ---- Build Python backend venv ----
WORKDIR /app/platform
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip
RUN if [ -f requirements.txt ]; then pip install -r requirements.txt; \
    elif [ -f pyproject.toml ]; then pip install .; \
    else echo "No requirements.txt or pyproject.toml in /platform" && exit 1; fi


# =========================
# RUNTIME STAGE
# =========================
FROM python:3.11-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    default-libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app /app
COPY --from=build /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    NODE_ENV=production

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
