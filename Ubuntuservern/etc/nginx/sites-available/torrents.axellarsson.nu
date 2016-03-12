server {
    server_name torrents.axellarsson.nu;

    location / {
	proxy_pass http://localhost:9091;
    }
}
