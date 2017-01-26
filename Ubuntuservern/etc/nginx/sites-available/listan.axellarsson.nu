server {
  listen 80;
  server_name listan.axellarsson.nu;
  return 301 https://$host$request_uri;
}

# Web socket stuff: the header field in a request to the proxied server depends on
# the presence of the "Upgrade" field in the client request header and not hardcoded
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}

server {
  listen 443 ssl http2;

  server_name listan.axellarsson.nu;

  root /var/www/listan.axellarsson.nu/;

  location = / {
    index index.html;
  }

  location /api/login {
    proxy_pass http://localhost:9002;
  }

  location /api/ws {
    # WebSocket Support
    proxy_pass http://localhost:9002;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_read_timeout 86400;
    proxy_set_header X-Real-IP $proxy_add_x_forwarded_for;
  }

  # redirect 404
  error_page 404 /404.html;

  # redirect server error pages to the static page /50x.html
  error_page 500 502 503 504 /50x.html;
  location = /50x.html {
    root /usr/share/nginx/html;
  }
}
