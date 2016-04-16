# Redirect http -> https
server {
    listen 80;
    server_name torrents.axellarsson.nu;

    # Redirect all HTTP requests to HTTPS with a 301 Moved Permanently response.
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;

    server_name torrents.axellarsson.nu;

    location / {
	proxy_pass http://localhost:9091;
    }
}
