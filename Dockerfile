FROM php:8.0.8-fpm-alpine

# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN apk --update add --no-cache \
		$PHPIZE_DEPS \
		freetype-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
        postgresql-dev \
		oniguruma-dev \
		gd-dev \
		zip \
		icu-dev \
	&& docker-php-ext-configure gd --with-jpeg --with-freetype  \
	&& docker-php-ext-configure zip --with-zip \
	&& docker-php-ext-install -j "$(nproc)" \
		bcmath \
		exif \
		gd \
		mbstring \
		opcache \
		pdo \
        pdo_mysql \
        pgsql \
        pdo_pgsql \
        mysqli \
		zip \
		intl \
    && apk del \
        autoconf \
        binutils \
        db \
        file \
        g++ \
        gcc \
        gmp \
        isl \
        libatomic \
        libbz2 \
        libc-dev \
        libffi \
        libgcc \
        libgomp \
        libldap \
        libmagic \
        libsasl \
        libstdc++ \
        m4 \
        make \
        mpc1 \
        musl-dev \
        perl \
        pkgconf \
        pkgconfig \
        re2c \
        sqlite-libs \
        zlib-dev \
        || true \
	&& docker-php-ext-configure bcmath --enable-bcmath \
	# fix work iconv library with alphine
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv \
	&& pecl install -o -f redis \
	&& docker-php-ext-enable redis \
	#&& apk del .build-deps \
	&& rm -rf /tmp/pear /tmp/* /var/cache/apk/*

COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer \
    LD_PRELOAD=/usr/lib/preloadable_libiconv.so

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer self-update \
    # set user ids
    && apk --no-cache add shadow \
    && usermod -u 102 www-data \
    && groupmod -g 101 www-data \
    && apk del shadow \
    #create php-fpm logs directory
    && mkdir /var/log/php-fpm

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.enable_cli=1'; \
        #echo 'opcache.jit_buffer_size=50M'; \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini \
	&& { \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini \
    && { \
        echo 'expose_php = off'; \
		echo 'upload_max_filesize=1000M'; \
		echo 'post_max_size=1000M'; \
		echo 'date.timezone = Europe/Moscow'; \
		echo 'memory_limit = -1'; \
	} > /usr/local/etc/php/conf.d/local.ini

WORKDIR /var/www
EXPOSE 9000

CMD ["php-fpm"]
