FROM node:22-slim

ENV NODE_ENV=production PORT=10000
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --chown=node:node src ./src

USER node
EXPOSE 10000
CMD ["npm", "start"]
