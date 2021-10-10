### Installation des packages nécessaires ###
sudo -S dnf update
sudo -S dnf install podman podman-compose git certbot  cronie cronie-anacron python3-certbot-dns-ovh 

### Creation des dossiers ###
mkdir -p containers/nextcloud/{db,html,nginx/ssl} && mkdir -p letsencrypt/log && mkdir -p ~/.config/systemd/user/

### Copie des fichier sur l'hote ###
git clone https://github.com/fma388/PodCloud.git
cp PodCloud/Services/* ~/.config/systemd/user/
cp PodCloud/containers/nextcloud/nginx/nginx.conf /home/sysadmin/containers/nextcloud/nginx/

### Création des certificats SSL ###
	# test
certbot --config-dir /home/sysadmin/letsencrypt/ --work-dir /home/sysadmin/letsencrypt/ --logs-dir /home/sysadmin/letsencrypt/log/ certonly --dns-ovh -d nextcloud.isshin.ovh --server https://acme-staging-v02.api.letsencrypt.org/directory --dns-ovh-credentials /home/sysadmin/letsencrypt/.ovhapi --non-interactive --email a.garde@outlook.com --no-eff-email --agree-tos

	# Definitif
#certbot --config-dir /home/sysadmin/letsencrypt/ --work-dir /home/sysadmin/letsencrypt/ --logs-dir /home/sysadmin/letsencrypt/log/ certonly --dns-ovh -d nextcloud.isshin.ovh --server https://acme-v02.api.letsencrypt.org/directory --dns-ovh-credentials /home/sysadmin/letsencrypt/.ovhapi --non-interactive --email a.garde@outlook.com --no-eff-email --agree-tos

cp /home/sysadmin/letsencrypt/live/nextcloud.isshin.ovh/fullchain.pem /home/sysadmin/containers/nextcloud/nginx/ssl
cp /home/sysadmin/letsencrypt/live/nextcloud.isshin.ovh/privkey.pem /home/sysadmin/containers/nextcloud/nginx/ssl


### Mise en place des taches crontab ###
(crontab -l 2>/dev/null; echo "0 13 * * * /usr/bin/certbot --config-dir /home/sysadmin/letsencrypt/ --work-dir /home/sysadmin/letsencrypt/ --logs-dir /home/sysadmin/letsencrypt/log/ renew --quiet") | crontab -
(crontab -l 2>/dev/null; echo "02 13 * * * cp -u /home/sysadmin/letsencrypt/live/nextcloud.isshin.ovh/fullchain.pem /home/sysadmin/ssl-nginx") | crontab -
(crontab -l 2>/dev/null; echo "02 13 * * * cp -u /home/sysadmin/letsencrypt/live/nextcloud.isshin.ovh/privkey.pem /home/sysadmin/nginx-ssl") | crontab -

### Ouverture ports pare-feu ###
sudo -S firewall-cmd --add-port=8080/tcp --permanent
sudo -S firewall-cmd --add-port=8443/tcp --permanent
sudo -S firewall-cmd --reload

### Mise en place des services et lancement ###
systemctl enable --user pod-nextcloud.service
systemctl start --user pod-nextcloud.service
	#Pour autoriser le lancement des services utilisateurs au démarrage
loginctl enable-linger sysadmin

### Commandes post-install ###
sleep 600
podman exec -it -u www-data nextcloud-app php occ maintenance:install --database "mysql" --database-host "127.0.0.1" --database-name "nextcloud" --database-user "nextcloud" --database-pass "nextcloud" --admin-pass "password" --data-dir "/var/www/html"
podman exec -it -u www-data nextcloud-app php occ config:system:set trusted_domains 1 --value=192.168.0.42
podman exec -it -u www-data nextcloud-app php occ config:system:set trusted_domains 2 --value=nextcloud.isshin.ovh
podman exec -it -u www-data nextcloud-app php occ config:system:set trusted_domains 3 --value=cloud.isshin.ovh
podman exec -it -u www-data nextcloud-app php occ config:system:set default_phone_region --value=FR
podman exec -it -u www-data nextcloud-app php occ config:system:set check_data_directory_permissions --value="false" --type=boolean

### Modification des droits du dossier d'installation ###
sudo -S chmod 775 ~/containers/nextcloud/html

### Redemarrage du pod ###
systemctl restart --user pod-nextcloud.service

### IDEE POUR LE REMPLISSAGE AUTOMATIQUE DES VARIABLES ###

#Créer un fichier de variable et demander à l'utilisateur de rentrer ses choix pour chaque variable. commande read
#Utiliser ensuite ses variables pour remplir les fichiers