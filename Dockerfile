FROM alpine:3.5

MAINTAINER Spicer Mathtews <spicer@cloudmanic.com>

ARG P_UID=33
ARG P_GID=33

ENV NGINX_VERSION 1.11.10

# Essential pkgs
RUN apk add --no-cache openssh-client git tar php7-fpm curl bash vim

# Essential php magic
RUN apk add --no-cache php7-curl php7-dom php7-gd php7-ctype php7-zip php7-xml php7-iconv php7-sqlite3 php7-mysqli php7-pgsql php7-pdo_pgsql php7-json php7-phar php7-openssl php7-pdo php7-mcrypt php7-pdo php7-pdo_pgsql php7-pdo_mysql php7-opcache php7-zlib php7-mbstring php7-session php7-intl php7-gettext php7-pcntl php7-posix

# Composer
RUN curl --silent --show-error --fail --location \
      --header "Accept: application/tar+gzip, application/x-gzip, application/octet-stream" \
      "https://getcomposer.org/installer" \
    | php7 -- --install-dir=/usr/bin --filename=composer

# Build and install Nginx
RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
	&& CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/logs/nginx.error.log \
		--http-log-path=/logs/nginx.access.log \
		--pid-path=/tmp/nginx.pid \
		--lock-path=/tmp/nginx.lock \
		--http-client-body-temp-path=/nginx-cache/client_temp \
		--http-proxy-temp-path=/nginx-cache/proxy_temp \
		--http-fastcgi-temp-path=/nginx-cache/fastcgi_temp \
		--http-uwsgi-temp-path=/nginx-cache/uwsgi_temp \
		--http-scgi-temp-path=/nginx-cache/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-http_perl_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-file-aio \
		--with-http_v2_module \
	" \
	&& apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		perl-dev \
	&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEYS" \
	&& gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -r "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./configure $CONFIG --with-debug \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& mv objs/nginx objs/nginx-debug \
	&& mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
	&& mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
	&& mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
	&& mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
	&& mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
	&& ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
	&& install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
	&& install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
	&& install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
	&& install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ 


# Copy over default configs for nginx.
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx-default.conf /etc/nginx/conf.d/default.conf

# Link php
RUN set -x \
	&& ln -s /usr/bin/php7 /usr/bin/php

# Reset Password and group files
RUN set -x \
      && echo "root:x:0:0:root:/root:/bin/ash" > /etc/passwd \
      && echo "root:::0:::::" > /etc/shadow \
      && echo "root:x:0:root" > /etc/group 
      
# Ensure www-data user exists
RUN set -x \ 
  && addgroup -g ${P_GID} -S www-data \
  && adduser -u ${P_UID} -D -S -G www-data www-data 
   
# Setup directory and Set perms for document root.
RUN set -x \
  && mkdir /www \   
  && mkdir /nginx-cache \ 
  && chown -R www-data:www-data /www \
  && chown -R www-data:www-data /logs \
  && chown -R www-data:www-data /nginx-cache      

# Copy over default files
COPY index.php /www/public/index.php
COPY php.ini /etc/php7/php.ini
COPY php-fpm.conf /etc/php7/php-fpm.conf
COPY php-fpm-www.conf /etc/php7/php-fpm.d/www.conf

# Copy the file that gets called when we start
COPY start.sh /start.sh
RUN chmod 755 /start.sh && chown www-data:www-data /start.sh

# Set port we run on because we run as a user.
EXPOSE 8080

# This needs to be at the bottom. 
USER www-data

# Workint directory
WORKDIR /www   

# Start the server
CMD ["/start.sh"]
