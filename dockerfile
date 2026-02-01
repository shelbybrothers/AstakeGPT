FROM node:18-bullseye AS build
WORKDIR /app

ENV CI=true \
    HUSKY=0 \
    SKIP_ENV_VALIDATION=1 \
    DATABASE_URL="postgresql://user:pass@127.0.0.1:5432/db?schema=public" \
    NEXTAUTH_SECRET="build-time-dummy-secret"

COPY . .

WORKDIR /app/next
RUN npm ci --no-audit --no-fund
RUN npx prisma generate
RUN npm run build


FROM node:18-bullseye AS runtime
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip supervisor \
  && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production \
    PYTHONUNBUFFERED=1 \
    HUSKY=0

COPY . /app
COPY --from=build /app/next/.next /app/next/.next
COPY --from=build /app/next/node_modules /app/next/node_modules
COPY --from=build /app/next/package.json /app/next/package.json
COPY --from=build /app/next/next.config.mjs /app/next/next.config.mjs
COPY --from=build /app/next/prisma /app/next/prisma

WORKDIR /app/backend
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip \
 && /opt/venv/bin/pip install -r requirements.txt

ENV PATH="/opt/venv/bin:${PATH}"

WORKDIR /app
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 3000
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
