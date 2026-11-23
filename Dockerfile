FROM node:24-alpine AS build
WORKDIR /build
COPY preview/package*.json preview/
RUN npm ci --prefix preview
COPY preview/ preview/
COPY desktop/day-core.cjs desktop/day-core.cjs
COPY index.html index.html
RUN npm run build --prefix preview

FROM nginxinc/nginx-unprivileged:stable-alpine
COPY --from=build /build/FRI-liquid-glass.html /usr/share/nginx/html/index.html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
