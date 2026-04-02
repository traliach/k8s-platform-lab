# Stage 1 — build React client
FROM node:20-alpine AS builder
WORKDIR /app/client
COPY client/package.json client/package-lock.json* ./
RUN npm install
COPY client/ ./
RUN npm run build

# Stage 2 — production Express server
FROM node:20-alpine AS runner
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev
COPY server/ ./server/
COPY --from=builder /app/client/dist ./client/dist

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3000
CMD ["node", "server/index.js"]
