#!/bin/sh -em

# parse value to boolean
# if cannot parse, return false
bool () {
  value=$(echo $1 | tr '[:upper:]' '[:lower:]')
  case $value in
    ("yes"|"y"|"true"|"0")
      return 0
      ;;
    (*)
      return 1
      ;;
  esac
}

# nginx default site conf
DEFAULT_CONF=/etc/nginx/conf.d/default.conf

# validate if default.conf or conf.d is mounted
[ ! -z "$(mount | grep /etc/nginx/conf.d/default.conf)" ] && MOUNTED=y
[ ! -z "$(mount | grep /etc/nginx/conf.d)" ] && MOUNTED=y

# if not mounted, will create a new default.conf
if ! bool "$MOUNTED"; then

   # empty file
   echo -n > $DEFAULT_CONF

   # directives
   echo "server_tokens off;" >> $DEFAULT_CONF
   echo "" >> $DEFAULT_CONF
   echo "proxy_set_header Host \$host;" >> $DEFAULT_CONF
   echo "proxy_set_header X-Real-IP \$remote_addr;" >> $DEFAULT_CONF
   echo "proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> $DEFAULT_CONF
   echo "proxy_set_header X-Forwarded-Proto \$scheme;" >> $DEFAULT_CONF
   echo "proxy_set_header X-NginX-Proxy true;" >> $DEFAULT_CONF
   echo "" >> $DEFAULT_CONF
   echo "rewrite_log on;" >> $DEFAULT_CONF
   echo "" >> $DEFAULT_CONF
   echo "add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains\" always;" >> $DEFAULT_CONF
   echo "ssl_session_cache shared:SSL:10m;" >> $DEFAULT_CONF
   echo "ssl_session_timeout 10m;" >> $DEFAULT_CONF
   echo "ssl_protocols TLSv1 TLSv1.1 TLSv1.2;" >> $DEFAULT_CONF
   echo "ssl_ciphers HIGH:!aNULL:!MD5;" >> $DEFAULT_CONF

   if bool "$HTTPS"; then
     # create self-signed certificate if not exists
     if [ ! -f /etc/nginx/conf.d/localhost.key.pem ]; then
       openssl req -new -x509 -sha256 -nodes -newkey rsa:4096 -days 66474 \
               -keyout /etc/nginx/conf.d/localhost.key.pem \
               -out /etc/nginx/conf.d/localhost.cert.pem \
               -subj "/C=US/ST=CA/L=San Francisco/O=Docker, Inc/OU=Nginx/CN=localhost/emailAddress=root@localhost"
     fi

     # add directives certificate
     echo "" >> $DEFAULT_CONF
     echo "ssl_certificate /etc/nginx/conf.d/localhost.cert.pem;" >> $DEFAULT_CONF
     echo "ssl_certificate_key /etc/nginx/conf.d/localhost.key.pem;" >> $DEFAULT_CONF
   fi

   # server directive
   echo "" >> $DEFAULT_CONF
   echo "server {" >> $DEFAULT_CONF
   echo "" >> $DEFAULT_CONF

   # https ?
   if bool "$HTTPS"; then
     echo "  listen 443 ssl;" >> $DEFAULT_CONF
   else
     echo "  listen 80;" >> $DEFAULT_CONF
   fi

   echo "  server_name localhost;" >> $DEFAULT_CONF
   echo "" >> $DEFAULT_CONF
   echo "  resolver 127.0.0.11 valid=30s;" >> $DEFAULT_CONF // to check
   echo "" >> $DEFAULT_CONF
   echo "  location / {" >> $DEFAULT_CONF
   echo "    root /usr/share/nginx/html;" >> $DEFAULT_CONF
   echo "    index index.html index.htm;" >> $DEFAULT_CONF
   echo "  }" >> $DEFAULT_CONF
   echo "" >> $DEFAULT_CONF
   echo "  error_page 500 502 503 504 /50x.html;" >> $DEFAULT_CONF
   echo "  location = /50x.html {" >> $DEFAULT_CONF
   echo "    root /usr/share/nginx/html;" >> $DEFAULT_CONF
   echo "  }" >> $DEFAULT_CONF

   # proxies
   if [ ! -z "$CCC_ADDRESS" ]; then
     echo "" >> $DEFAULT_CONF
     echo "  location ~ /api/v1/conversions(.*)\$ {" >> $DEFAULT_CONF
     echo "    set \$backend $CCC_ADDRESS;" >> $DEFAULT_CONF
     echo "    proxy_pass http://\$backend/v1/conversions\$1;" >> $DEFAULT_CONF
     echo "    proxy_redirect off;" >> $DEFAULT_CONF
     echo "  }" >> $DEFAULT_CONF
     echo "  location ~ /api/v1/tickers(.*)\$ {" >> $DEFAULT_CONF
     echo "    set \$backend $CCC_ADDRESS;" >> $DEFAULT_CONF
     echo "    proxy_pass http://\$backend/v1/tickers\$1;" >> $DEFAULT_CONF
     echo "    proxy_redirect off;" >> $DEFAULT_CONF
     echo "  }" >> $DEFAULT_CONF
   fi

   if [ ! -z "$API_ADDRESS" ]; then
     echo "" >> $DEFAULT_CONF
     echo "  location ~ /api(.*)\$ {" >> $DEFAULT_CONF
     echo "    set \$backend $API_ADDRESS;" >> $DEFAULT_CONF
     echo "    proxy_pass http://\$backend\$1\$is_args\$args;" >> $DEFAULT_CONF
     echo "    proxy_redirect off;" >> $DEFAULT_CONF
     echo "  }" >> $DEFAULT_CONF
   fi

   echo "" >> $DEFAULT_CONF
   echo "}" >> $DEFAULT_CONF
fi

# start nginx
if [ ! -z "$1" ]; then
  /usr/sbin/nginx -g "daemon on;"
  exec "$@"
else
  /usr/sbin/nginx -g "daemon off;"
fi
