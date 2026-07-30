FROM node:22-alpine AS build

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS production
RUN addgroup -S vendure && adduser -S vendure -G vendure
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build --chown=vendure:vendure /app/dist ./dist
COPY --from=build --chown=vendure:vendure /app/static ./static
USER vendure
EXPOSE 3000
CMD ["node", "dist/index.js"]
