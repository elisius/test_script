#!/bin/bash
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                   Creating Default User           " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo useradd -s /bin/bash -m -d /home/tsm_user -c "tsm user" tsm_user
sudo usermod --password $(echo datasc13nc3 | openssl passwd -1 -stdin) tsm_user
sudo usermod -aG sudo tsm_user

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                       Getting updates                " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo apt-get update >> /setup.log
sudo apt-get -y install locales >> /setup.log
sudo apt-get -y install language-pack-en >> /setup.log

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "               Downloading Tableau Server             " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo wget https://downloads.tableau.com/esdalt/2021.4.3/tableau-server-2021-4-3_amd64.deb
sudo git clone https://elisiuslegodi:LEGODIse93*@gitlab.com/strategicinsights/forked/acme-sh.git ~/.acme.sh >> /setup.log
sudo apt-get -y install gdebi-core >> /setup.log

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                   Installing Tableau server           " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo gdebi -n tableau-server-2021-4-3_amd64.deb >> /setup.log
sudo rm tableau-server-2021-4-3_amd64.deb
sleep 150s
sudo /opt/tableau/tableau_server/packages/scripts.20214.22.0108.1039/initialize-tsm --accepteula -a tsm_user >> /setup.log
sleep 50s
source /etc/profile.d/tableau_server.sh

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                      Activating licenses              " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
## tsm licenses activate -k TSW6-B591-2CD0-9013-9D4E >> /setup.log
## tsm licenses activate -k TSVO-B25D-C730-ACE3-A70F >> /setup.log
## tsm licenses activate -k TSOL-B1D4-24D0-EFC9-6503 >> /setup.log
## tsm licenses activate -k TS69-B1CB-E770-5BE7-4565 >> /setup.log
## tsm licenses deactivate --license-key <product-key>
tsm licenses activate -t >> /setup.log

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                   Creating register file              " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "{ \"zip\" : \"7700\", \"country\" : \"South Africa\", \"city\" : \"Cape Town\", \"last_name\" : \"Legodi\", \"industry\" : \"Telco\", \"eula\" : \"yes\", \"title\" : \"Developer\", \"phone\" : \"0679389670\", \"company\" : \"Telkom\", \"state\" : \"Western Cape\", \"department\" : \"Insights\", \"first_name\" : \"Elisius\", \"email\" : \"elisius.legodi@telkom.co.za\"}" > ~/tab-reg.json
cat ~/tab-reg.json >> /setup.log
tsm register --file ~/tab-reg.json >> /setup.log

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                   Creating tableau ids            " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "{\"configEntities\": {\"identityStore\": {\"_type\": \"identityStoreType\",\"type\": \"local\"}}, \"configKeys\": {\"gateway.public.host\": \"tabtest.strategicinsights.co.za\", \"gateway.public.port\": \"80\", \"gateway.trusted\": \"34.159.111.31\",\"gateway.trusted_hosts\": \"www.tabtest.strategicinsights.co.za\"}}" > ~/tab-ids.json
cat ~/tab-ids.json >> /setup.log
tsm settings import -f ~/tab-ids.json >> /setup.log

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                   Applying pending changes            " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
tsm pending-changes apply >> /setup.log
tsm initialize --request-timeout 1800 >> /setup.log
sleep 10s
tsm stop >> /setup.log
sleep 5s

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "           Fetching and restoring tableau backup           " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
gsutil ls gs://tkg-tkm-tableau-dev-backups/ | sort -k 2 | tail -n 1 | head -1 | gsutil -m cp -I . >> /setup.log
mv *.tsbak /var/opt/tableau/tableau_server/data/tabsvc/files/backups/ >> /setup.log
source /etc/profile.d/tableau_server.sh
cd /var/opt/tableau/tableau_server/data/tabsvc/files/backups/
tsm maintenance restore --file *.tsbak >> /setup.log
sleep 10s
tsm authentication trusted configure -th "127.0.0.1", "localhost" >> /setup.log

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "           Cloning from git & installing Node & API           " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo git clone https://elisiuslegodi:LEGODIse93*@gitlab.com/strategicinsights/project-whaleshark-api.git /opt/api >> /setup.log
curl -sL https://deb.nodesource.com/setup_current.x | sudo -E bash - >> /setup.log
sudo apt-get install -y nodejs >> /setup.log
sudo apt-get install socat >> /setup.log
sleep 15s

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "           Generating Tableau Server Manager SSL Certificate           " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sleep 3s
cd ~/.acme.sh
sudo git checkout 2.9.0 >> /setup.log
sleep 10s
URL=tabtest.strategicinsights.co.za
sleep 2s
sudo bash acme.sh --issue -d $URL --standalone --force >> /setup.log
sleep 5s
sudo mkdir /opt/tableau/tableau_server/data/
sudo mkdir /opt/tableau/tableau_server/data/ssl/
sudo cp /root/.acme.sh/$URL/$URL.cer /opt/tableau/tableau_server/data/ssl/$URL.crt
sudo cp /root/.acme.sh/$URL/$URL.key /opt/tableau/tableau_server/data/ssl/$URL.key
sleep 10s
tsm security external-ssl enable --cert-file /opt/tableau/tableau_server/data/ssl/$URL.crt --key-file /opt/tableau/tableau_server/data/ssl/$URL.key >> /setup.log
tsm pending-changes apply >> /setup.log
sleep 5s

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                   Generating echo API SSL Certificate                 " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
cd ~/.acme.sh
URL=api.echo.tabtest.strategicinsights.co.za
sudo bash acme.sh --issue -d $URL --standalone --force >> /setup.log
sudo cp /root/.acme.sh/$URL/$URL.cer /opt/api/$URL.crt
sudo cp /root/.acme.sh/$URL/$URL.key /opt/api/$URL.key
sleep 2s
cd /opt/api
sudo git checkout root_update >> /setup.log
sudo npm install >> /setup.log
sudo sed -i 's/api.echo/api.echo.tabtest/g' /opt/api/app.js
sudo npm install pm2@latest -g >> /setup.log
sleep 10s
/bin/su -c "pm2 start /opt/api/app.js" - tsm_user >> /setup.log
pm2 startup -u tsm_user --hp /home/tsm_user >> /setup.log
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u tsm_user --hp /home/tsm_user >> /setup.log
pm2 save --force >> /setup.log
echo "source /etc/profile.d/tableau_server.sh" >> ~tsm_user/.bashrc
sudo mkdir /opt/tkg-tkm-tableau/
sudo mkdir /opt/tkg-tkm-tableau/logs/

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                   Setting Tableau Server data cache                   " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
tsm data-access caching set -r 15 >> /setup.log
sleep 10s
tsm pending-changes apply >> /setup.log

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "               Creating Tableau server backup script & log file        " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo mkdir /opt/tkg-tkm-tableau/
sudo mkdir /opt/tkg-tkm-tableau/logs/
sudo touch /opt/tkg-tkm-tableau/logs/backup.log
sudo gsutil cp gs://tableau-server-file-backups/backup.sh /opt/tkg-tkm-tableau/ >> /setup.log


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "           Creating SSL certificate renewal script & log file          " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo touch /opt/tkg-tkm-tableau/logs/ssl-renewal.log
sudo gsutil cp gs://tableau-server-file-backups/ssl-renewal.sh /opt/tkg-tkm-tableau/ >> /setup.log


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "               Making renewal.sh & backup.sh executable            " >> setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo chmod u+x /opt/tkg-tkm-tableau/*.sh

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                           Creating Cronjobs               " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
crontab -l | { cat; echo "0 0 1 */2 * bash /opt/tkg-tkm-tableau/ssl-renewal.sh >> /opt/tkg-tkm-tableau/logs/ssl-renewal.log 2>&1"; } | crontab -
crontab -l | { cat; echo "*/35 * * * * bash /opt/tkg-tkm-tableau/backup.sh >> /opt/tkg-tkm-tableau/logs/backup.log 2>&1"; } | crontab -

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "               Downloading & installing ODBC drivers           " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                               Oracle driver                   " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo wget https://downloads.tableau.com/drivers/linux/deb/tableau-driver/tableau-oracle_12.1.0.2.0_amd64.deb
sudo apt-get install -f >> /setup.log
sudo gdebi tableau-oracle_12.1.0.2.0_amd64.deb --n >> /setup.log
sudo rm tableau-oracle_12.1.0.2.0_amd64.deb
sleep 5s

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                           Postgresql driver                   " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo wget https://downloads.tableau.com/drivers/linux/deb/tableau-driver/tableau-postgresql-odbc_09.06.0501_amd64.deb
sudo gdebi tableau-postgresql-odbc_09.06.0501_amd64.deb --n >> /setup.log
sudo rm tableau-postgresql-odbc_09.06.0501_amd64.deb
sleep 5s

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                       MicrosoftSQL driver                 " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list > /etc/apt/sources.list.d/mssql-release.list >> /setup.log
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17
source ~/.bashrc
sleep 5s

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                           MySQL driver                    " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
sudo apt install odbcinst >> /setup.log
sudo apt install unixodbc >> /setup.log
sudo wget https://downloads.mysql.com/archives/get/p/10/file/mysql-connector-odbc-5.3.13-linux-ubuntu18.04-x86-64bit.tar.gz
sudo tar -zxvf mysql-connector-odbc-5.3.13-linux-ubuntu18.04-x86-64bit.tar.gz
cd mysql-connector-odbc-5.3.13-linux-ubuntu18.04-x86-64bit/
sudo cp -r bin/* /usr/local/bin/
sudo cp -r lib/* /usr/local/lib/
sudo myodbc-installer -a -d -n "MySQL ODBC 5.3.13 Unicode Driver" -t "Driver=/usr/local/lib/libmyodbc5w.so"
sudo myodbc-installer -a -d -n "MySQL ODBC 5.3.13 ANSI Driver" -t "Driver=/usr/local/lib/libmyodbc5a.so"
sudo rm /mysql-connector-odbc-5.3.13-linux-ubuntu18.04-x86-64bit.tar.gz
sleep 30s

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
echo "                           Starting Tableau Server                    " >> /setup.log
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /setup.log
tsm start >> /setup.log
