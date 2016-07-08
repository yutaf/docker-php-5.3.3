# tag: yutaf/php-5.3.3
FROM centos:6
MAINTAINER yutaf <yutafuji2008@gmail.com>

RUN yum update -y
RUN yum install -y \
  gcc \
  ImageMagick \
  ImageMagick-devel \
# php
  php \
  php-mysql \
  php-devel \
  php-mbstring \
  php-pear \
# mysql
  mysql \
  mysql-server \
# cron
  crontabs.noarch

RUN printf "\n" | pecl install imagick-3.1.2

# workaround for curl certification error
COPY templates/ca-bundle-curl.crt /root/ca-bundle-curl.crt

# xdebug
RUN \
  mkdir -p /usr/local/src/xdebug && \
  cd /usr/local/src/xdebug && \
  curl --cacert /root/ca-bundle-curl.crt -L -O http://xdebug.org/files/xdebug-2.2.7.tgz && \
  tar -xzf xdebug-2.2.7.tgz && \
  cd xdebug-2.2.7 && \
  phpize && \
  ./configure --enable-xdebug && \
  make && \
  make install && \
  cd && \
  rm -r /usr/local/src/xdebug

# php.ini
RUN \
  sed -i 's;^expose_php.*;expose_php = Off;' /etc/php.ini && \
  echo 'zend_extension=/usr/lib64/php/modules/xdebug.so' >> /etc/php.ini && \
  echo 'extension=imagick.so' >> /etc/php.ini && \
# composer
  echo 'curl.cainfo=/root/ca-bundle-curl.crt' >> /etc/php.ini && \
  echo 'openssl.cafile=/root/ca-bundle-curl.crt' >> /etc/php.ini && \
# xdebug
  echo 'html_errors = on' >> /etc/php.ini && \
  echo 'xdebug.remote_enable  = on' >> /etc/php.ini && \
  echo 'xdebug.remote_autostart = 1' >> /etc/php.ini && \
  echo 'xdebug.remote_connect_back=1' >> /etc/php.ini && \
  echo 'xdebug.remote_handler = dbgp' >> /etc/php.ini && \
  echo 'xdebug.idekey = PHPSTORM' >> /etc/php.ini

# Edit config files
RUN \
# Apache config
  sed -i 's;^#ServerName .*;ServerName localhost:80;' /etc/httpd/conf/httpd.conf && \
  mkdir -p /var/www/html/htdocs && \
  sed -i 's;^DocumentRoot .*;DocumentRoot "/var/www/html/htdocs";' /etc/httpd/conf/httpd.conf && \
  sed -i 's;^<Directory "/var/www/html">;<Directory "/var/www/html/htdocs">;' /etc/httpd/conf/httpd.conf && \
  mkdir -p -m 777 /var/www/html/log/ && \
  sed -i 's;^CustomLog .*;CustomLog "|/usr/sbin/rotatelogs /var/www/html/log/access.%Y%m%d.log 86400 540" combined;' /etc/httpd/conf/httpd.conf && \
  sed -i 's;^ErrorLog .*;ErrorLog "|/usr/sbin/rotatelogs /var/www/html/log/error.%Y%m%d.log 86400 540";' /etc/httpd/conf/httpd.conf && \
  sed -i 's;^ServerTokens .*;ServerTokens Prod;' /etc/httpd/conf/httpd.conf && \
# Create php scripts for check
  echo "<?php echo 'hello, php';" > /var/www/html/htdocs/index.php && \
  echo "<?php phpinfo();" > /var/www/html/htdocs/info.php && \
# set TERM
  echo export TERM=xterm-256color >> /root/.bashrc && \
# set timezone
  ln -sf /usr/share/zoneinfo/Japan /etc/localtime && \
# Delete log files except dot files
  echo '00 15 * * * find /var/www/html/log -not -regex ".*/\.[^/]*$" -type f -mtime +2 -exec rm -f {} \;' > /root/crontab && \
  crontab /root/crontab && \
# mysql
  echo >> /etc/my.cnf && \
  echo '[client]' >> /etc/my.cnf && \
  echo 'default-character-set=utf8' >> /etc/my.cnf && \
  sed -i 's;^\[mysqld\];&\ncharacter-set-server=utf8\ncollation-server=utf8_general_ci;' /etc/my.cnf && \
# alternative to　"mysql_secure_installation"
  /etc/init.d/mysqld start && \
  mysqladmin -u root password "root" && \
  mysql -u root -proot -e "DELETE FROM mysql.user WHERE User='';" && \
  mysql -u root -proot -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1');" && \
  mysql -u root -proot -e "DROP DATABASE test;" && \
  mysql -u root -proot -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" && \
  /etc/init.d/mysqld stop

CMD ["/bin/bash", "-c", "/etc/init.d/mysqld start && /etc/init.d/crond start && /usr/sbin/httpd -DFOREGROUND"]
