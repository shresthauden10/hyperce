FROM node:22-alpine AS base
WORKDIR /app
COPY package*.json ./

FROM base AS dependencies
RUN npm ci

FROM dependencies AS development
ENV NODE_ENV=development
RUN mkdir -p /app/.tanstack/tmp /app/src/gql && chmod -R 777 /app/.tanstack /app/src
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

FROM dependencies AS build
COPY . .
RUN npm run build

FROM node:22-alpine AS production
RUN addgroup -S vendure && adduser -S vendure -G vendure
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev && \
    rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack
COPY --from=build --chown=vendure:vendure /app/dist ./dist
COPY --from=build --chown=vendure:vendure /app/static ./static
RUN mkdir -p /app/static/assets && chown -R vendure:vendure /app/static/assets
USER vendure
EXPOSE 3000
CMD ["node", "dist/index.js"]