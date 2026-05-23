FROM nginx:alpine

# Install tools for debugging
RUN apk add --no-cache bash curl iproute2 tcpdump

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create content directory
RUN mkdir -p /var/www/dash

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
