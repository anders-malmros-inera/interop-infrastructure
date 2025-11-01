FROM nginx:stable-alpine
LABEL org.opencontainers.image.title="interop-infrastructure-openapi"
LABEL org.opencontainers.image.description="Static server for the service-catalog OpenAPI files"

# Copy all files in this directory into nginx html root
COPY . /usr/share/nginx/html/

EXPOSE 80

# Use the default nginx command
CMD ["nginx", "-g", "daemon off;"]
