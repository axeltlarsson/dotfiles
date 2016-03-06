server {
    server_name recept.axellarsson.nu;

    root /var/www/recept.axellarsson.nu/;


    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to displaying a 404.
        set $page_to_view "/index.php";
        try_files $uri $uri/ @rewrites;
    }

    error_page 404 /404.php;

    # redirect server error pages to the static page /50x.html

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
           root /usr/share/nginx/html;
    }

    location ~ \.php$ {
       fastcgi_split_path_info ^(.+\.php)(/.+)$;

       try_files = $uri @missing;

       # With php5-fpm:
       fastcgi_pass unix:/var/run/php5-fpm.sock;
       fastcgi_index index.php;
       include fastcgi_params;
    }

    location @missing {
       rewrite ^ $scheme://$host/index.php permanent;
    }

    # rewrites
    location @rewrites {
        if ($uri ~* ^/([a-z]+)$) {
            set $page_to_view "/$1.php";
            rewrite ^/([a-z]+)$ /$1.php last;
        }
    }
}


