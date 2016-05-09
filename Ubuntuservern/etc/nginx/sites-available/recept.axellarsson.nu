# Redirect http -> https
server {
    listen 80;
    server_name recept.axellarsson.nu;

    # Redirect all HTTP requests to HTTPS with a 301 Moved Permanently response.
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;

    server_name recept.axellarsson.nu;

    root /var/www/recept.axellarsson.nu/;

    location / {
	# fist attempt URL then try as php file
        try_files $uri @extensionless-php;
    }

    location = / {
        index recipes.php;
    }

    error_page 404 /404.php;

    # redirect server error pages to the static page /50x.html

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
           root /usr/share/nginx/html;
    }

    location ~ \.php$ {
       fastcgi_split_path_info ^(.+\.php)(/.+)$;

       try_files $uri =404;

       # With php5-fpm:
       fastcgi_pass unix:/var/run/php5-fpm.sock;
       fastcgi_index index.php;
       include fastcgi_params;
       fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
    }

    # Rewrite so that /file fetches /file.php
    location @extensionless-php {
       rewrite ^(.*)$ $1.php last;
    }

}

