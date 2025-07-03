sudo docker run -d \
  --name nginx-check \
  --restart unless-stopped \
  -p 80:80 \
  --rm \
  nginx:alpine sh -c 'echo "Hello, world!" > /usr/share/nginx/html/index.html && exec nginx -g "daemon off;"'
