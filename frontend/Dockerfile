# Build stage
FROM node:18-alpine AS build-stage
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (npm ci 대신 npm install 사용)
RUN npm install

# Copy source code
COPY . .

# Build arguments for OpenTelemetry
ARG VUE_APP_OTEL_EXPORTER_OTLP_ENDPOINT="http://collector.lgtm.20.249.154.255.nip.io"
ARG VUE_APP_OTEL_SERVICE_NAME=aks-demo-frontend
ARG VUE_APP_OTEL_SERVICE_VERSION=1.0.0
ARG VUE_APP_OTEL_ENVIRONMENT=production

# Set environment variables for build
ENV VUE_APP_OTEL_EXPORTER_OTLP_ENDPOINT=$VUE_APP_OTEL_EXPORTER_OTLP_ENDPOINT
ENV VUE_APP_OTEL_SERVICE_NAME=$VUE_APP_OTEL_SERVICE_NAME
ENV VUE_APP_OTEL_SERVICE_VERSION=$VUE_APP_OTEL_SERVICE_VERSION
ENV VUE_APP_OTEL_ENVIRONMENT=$VUE_APP_OTEL_ENVIRONMENT

# Build the app
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=build-stage /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"] 