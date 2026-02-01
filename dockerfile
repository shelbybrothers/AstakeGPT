FROM node:20-bullseye AS build
WORKDIR /app

RUN apt-get update && apt-get install -y python3 python3-pip python3-venv && rm -rf /var/lib/apt/lists/*

COPY . .

# Build frontend
WORKDIR /app/next
RUN npm ci
RUN npm run build

# Install backend deps
WORKDIR /app/platform
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip
RUN if [ -f requirements.txt ]; then pip install -r requirements.txt; \
    elif [ -f pyproject.toml ]; then pip install .; \
    else echo "No requirements.txt or pyproject.toml in /platform" && exit 1; fi

FROM node:20-bullseye
WORKDIR /app

RUN apt-get update && apt-get install -y python3 supervisor && rm -rf /var/lib/apt/lists/*

COPY --from=build /app /app
COPY --from=build /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 3000
CMD ["/usr/bin/supervisord","-n"]
