#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root. The following commands need root access: apt, make, ldconfig, systemctl, mv,and mkdir"
  exit
fi
sudo apt update
sudo apt upgrade
sudo apt install build-essential libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin libossp-uuid-dev libvncserver-dev freerdp2-dev libssh2-1-dev libtelnet-dev libwebsockets-dev libpulse-dev libvorbis-dev libwebp-dev libssl-dev libpango1.0-dev libswscale-dev libavcodec-dev libavutil-dev libavformat-dev tomcat9 tomcat9-admin tomcat9-common tomcat9-user tigervnc-standalone-server apache2 nano xfce4 xfce4-goodies certbot python3-certbot-apache
wget http://mirror.cc.columbia.edu/pub/software/apache/guacamole/1.2.0/source/guacamole-server-1.2.0.tar.gz
tar -xvf guacamole-server-1.2.0.tar.gz
sudo rm guacamole-server-1.2.0.tar.gz
cd guacamole-server-1.2.0
./configure --with-init-dir=/etc/init.d
sudo make
sudo make install
sudo ldconfig
sudo systemctl daemon-reload
sudo systemctl start guacd
sudo systemctl enable guacd
wget https://downloads.apache.org/guacamole/1.2.0/binary/guacamole-1.2.0.war
sudo mv guacamole-1.2.0.war /var/lib/tomcat9/webapps/guacamole.war
sudo systemctl restart tomcat9 guacd
sudo mkdir /etc/guacamole/
echo "Opening /etc/guacamole/guacamole.properties"
echo "Would you like to edit guacamole.properties or use default settings? [Y/n]"
read -r "edit_guac.prop"
if [[ "$edit_guac.prop" == "Y" ]]; then
  sudo "${EDITOR:-nano}" /etc/guacamole/guacamole.properties
elif [[ "$edit_guac.prop" == "n" ]]; then
  sudo echo -n "
# Hostname and port of guacamole proxy
guacd-hostname: localhost
guacd-port:     4822

# Auth provider class (authenticates user/pass combination, needed if using the provided login screen)
auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
basic-user-mapping: /etc/guacamole/user-mapping.xml
" >> /etc/guacamole/guacamole.properties
fi
echo "In the next step, you are required to manually add your preferred username and password for the guacamole login."
sleep 2s
echo "Enter your preferred password for guacamole (it does not have to be your system login)"
sudo touch /etc/guacamole/user-mapping.xml
read -r "md5password"
sudo echo -n "$md5password" | openssl md5 >> /etc/guacamole/user-mapping.xml
echo "You must now specify your username and password. Please enter the md5 hash generated for you (your password) in the password text field. The username should not be md5 hash. The password MUST be a md5 hash."
sleep 8s
sudo "${EDITOR:-nano}" /etc/guacamole/user-mapping.xml
sudo systemctl restart tomcat9 guacd
vncserver
echo "Have you just created a new vncserver password? [Y/n]"
read -r "vncservernew"
if [[ "$vncservernew" == "Y" ]]; then
  echo -n "Edit the vnc-server text field with the vncserver password you have just created. It does not need to be an md5 hash."
  sleep 6s
  sudo "${EDITOR:-nano}" /etc/guacamole/user-mapping.xml
elif [[ "$vncservernew" == "n" ]]; then
echo "Continuing."
fi
sudo systemctl restart tomcat9 guacd
echo "Replace the username placeholder with your own username."
sleep 5s
sudo "${EDITOR:-nano}" /etc/systemd/system/vncserver@.service
vncserver -kill :1
sudo systemctl start vncserver@1.service
sudo systemctl enable vncserver@1.service
sudo a2enmod proxy proxy_http headers proxy_wstunnel
sudo touch /etc/apache2/sites-available/guacamole.conf
sudo echo "<VirtualHost *:80>
      ServerName 127.0.0.1

      ErrorLog ${APACHE_LOG_DIR}/guacamole_error.log
      CustomLog ${APACHE_LOG_DIR}/guacamole_access.log combined

      <Location />
          Require all granted
          ProxyPass http://localhost:8080/guacamole/ flushpackets=on
          ProxyPassReverse http://localhost:8080/guacamole/
      </Location>

     <Location /websocket-tunnel>
         Require all granted
         ProxyPass ws://localhost:8080/guacamole/websocket-tunnel
         ProxyPassReverse ws://localhost:8080/guacamole/websocket-tunnel
     </Location>

     Header always unset X-Frame-Options
</VirtualHost>" >> /etc/apache2/sites-available/guacamole.conf
sudo a2ensite guacamole.conf
sudo systemctl restart apache2