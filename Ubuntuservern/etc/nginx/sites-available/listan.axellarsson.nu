server {
    server_name listan.axellarsson.nu;

    root /var/www/listan.axellarsson.nu/;
   
    location ~ \.php$ {
       fastcgi_split_path_info ^(.+\.php)(/.+)$;

       # With php5-fpm:
       fastcgi_pass unix:/var/run/php5-fpm.sock;
       fastcgi_index index.php;
       include fastcgi_params;
    }
}
