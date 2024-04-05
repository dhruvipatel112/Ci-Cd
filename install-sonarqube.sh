#!/bin/bash

# Step 1: Install OpenJDK 11
sudo apt-get install openjdk-11-jdk -y

# Step 2: Install and Configure PostgreSQL
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
sudo apt install postgresql postgresql-contrib -y
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo passwd postgres
sudo -u postgres createuser sonar
sudo -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED password 'my_strong_password';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonar;"

# Step 3: Download and Install SonarQube
sudo apt-get install zip -y
VERSION_NUMBER="replace_with_version_number" # specify the version number
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$VERSION_NUMBER.zip
sudo unzip sonarqube-$VERSION_NUMBER.zip
sudo mv sonarqube-$VERSION_NUMBER /opt/sonarqube

# Step 4: Add SonarQube Group and User
sudo groupadd sonar
sudo useradd -d /opt/sonarqube -g sonar sonar
sudo chown sonar:sonar /opt/sonarqube -R

# Step 5: Configure SonarQube
sudo sed -i 's/#sonar.jdbc.username=/sonar.jdbc.username=sonar/' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's/#sonar.jdbc.password=/sonar.jdbc.password=my_strong_password/' /opt/sonarqube/conf/sonar.properties
sudo sed -i '$ a sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube' /opt/sonarqube/conf/sonar.properties

sudo sed -i 's/#RUN_AS_USER=/RUN_AS_USER=sonar/' /opt/sonarqube/bin/linux-x86-64/sonar.sh

# Step 6: Setup Systemd service
sudo tee /etc/systemd/system/sonar.service > /dev/null <<EOT
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=sonar
Group=sonar
Restart=always

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

sudo systemctl enable sonar
sudo systemctl start sonar

# Step 7: Modify Kernel System Limits
sudo tee -a /etc/sysctl.conf > /dev/null <<EOT
vm.max_map_count=262144
fs.file-max=65536
EOT
sudo sysctl -p

echo "Setup completed successfully!"
