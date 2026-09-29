#satge1:install dependencies

FROM node:20-alpine as build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

#stage2:copy source code and build
FROM node:20-alpine as build-stage
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY package.json ./
COPY app.js server.js ./
COPY public ./public

RUN rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/bin/npm /usr/local/bin/npx \
           /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg

USER 1000
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "server.js"]