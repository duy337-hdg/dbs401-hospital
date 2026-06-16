#!/bin/bash

# ============================================================
#   DBS401 Project - Hospital Management System Setup Script
#   Author: DBS401 Student
#   Description: Auto setup LAMP + Hospital Management System
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DB_NAME="myhmsdb"
DB_USER="hmsuser"
DB_PASS="hms123"
WEB_DIR="/var/www/html/hospital"
GITHUB_URL="https://github.com/kishan0725/Hospital-Management-System.git"

echo -e "${BLUE}"
echo "======================================================"
echo "   DBS401 - Hospital Management System Installer     "
echo "======================================================"
echo -e "${NC}"

# -----------------------------------------------
# STEP 1: Update package list
# -----------------------------------------------
echo -e "${YELLOW}[*] Updating package list...${NC}"
sudo apt update -y > /dev/null 2>&1
echo -e "${GREEN}[+] Package list updated.${NC}"

# -----------------------------------------------
# STEP 2: Check & Install Apache2
# -----------------------------------------------
echo -e "${YELLOW}[*] Checking Apache2...${NC}"
if systemctl is-active --quiet apache2; then
    echo -e "${GREEN}[+] Apache2 is already running. Skipping installation.${NC}"
else
    if dpkg -l | grep -q apache2; then
        echo -e "${GREEN}[+] Apache2 is installed but not running. Starting...${NC}"
        sudo systemctl start apache2
        sudo systemctl enable apache2
    else
        echo -e "${YELLOW}[*] Installing Apache2...${NC}"
        sudo apt install apache2 -y > /dev/null 2>&1
        sudo systemctl start apache2
        sudo systemctl enable apache2
        echo -e "${GREEN}[+] Apache2 installed and started.${NC}"
    fi
fi

# -----------------------------------------------
# STEP 3: Check & Install MariaDB (MySQL)
# -----------------------------------------------
echo -e "${YELLOW}[*] Checking MariaDB...${NC}"
if systemctl is-active --quiet mariadb; then
    echo -e "${GREEN}[+] MariaDB is already running. Skipping installation.${NC}"
else
    if dpkg -l | grep -q mariadb-server; then
        echo -e "${GREEN}[+] MariaDB is installed but not running. Starting...${NC}"
        sudo systemctl start mariadb
        sudo systemctl enable mariadb
    else
        echo -e "${YELLOW}[*] Installing MariaDB...${NC}"
        sudo apt install mariadb-server -y > /dev/null 2>&1
        sudo systemctl start mariadb
        sudo systemctl enable mariadb
        echo -e "${GREEN}[+] MariaDB installed and started.${NC}"
    fi
fi

# -----------------------------------------------
# STEP 4: Check & Install PHP
# -----------------------------------------------
echo -e "${YELLOW}[*] Checking PHP...${NC}"
if command -v php > /dev/null 2>&1; then
    echo -e "${GREEN}[+] PHP is already installed: $(php -r 'echo PHP_VERSION;'). Skipping.${NC}"
else
    echo -e "${YELLOW}[*] Installing PHP...${NC}"
    sudo apt install php php-mysqli libapache2-mod-php -y > /dev/null 2>&1
    echo -e "${GREEN}[+] PHP installed.${NC}"
fi

# -----------------------------------------------
# STEP 5: Check & Install Git
# -----------------------------------------------
echo -e "${YELLOW}[*] Checking Git...${NC}"
if command -v git > /dev/null 2>&1; then
    echo -e "${GREEN}[+] Git is already installed. Skipping.${NC}"
else
    echo -e "${YELLOW}[*] Installing Git...${NC}"
    sudo apt install git -y > /dev/null 2>&1
    echo -e "${GREEN}[+] Git installed.${NC}"
fi

# -----------------------------------------------
# STEP 6: Clone Web Source Code
# -----------------------------------------------
echo -e "${YELLOW}[*] Setting up web application...${NC}"
if [ -d "$WEB_DIR" ]; then
    echo -e "${YELLOW}[*] Web directory already exists. Removing and re-cloning...${NC}"
    sudo rm -rf "$WEB_DIR"
fi

sudo git clone "$GITHUB_URL" "$WEB_DIR" > /dev/null 2>&1
echo -e "${GREEN}[+] Web source cloned to $WEB_DIR${NC}"

# -----------------------------------------------
# STEP 7: Setup Database
# -----------------------------------------------
echo -e "${YELLOW}[*] Setting up database...${NC}"

# Create database and user
sudo mysql -u root <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME;
DROP USER IF EXISTS '$DB_USER'@'localhost';
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Import SQL file
sudo mysql -u root "$DB_NAME" < "$WEB_DIR/myhmsdb.sql"

# Add flags to database
sudo mysql -u root "$DB_NAME" << SQLEOF
ALTER TABLE admintb ADD COLUMN flag VARCHAR(100);
UPDATE admintb SET flag='FPT_DBS{1_SQL_1nj3ct10n_1s_34sy}' WHERE username='admin';
ALTER TABLE patreg ADD COLUMN flag VARCHAR(100);
INSERT INTO patreg(fname,lname,gender,email,contact,password,cpassword,flag) VALUES('Secret','Patient','Male','secret@hospital.com','0000000000','secret123','secret123','FPT_DBS{2_1D0R_p4t13nt_d4t4_l34k}');
INSERT INTO patreg(fname,lname,gender,email,contact,password,cpassword,flag) VALUES('admin','hidden','Male','hidden@hospital.com','0000000001','hidden123','hidden123','FPT_DBS{3_pr1v_3sc_4dm1n_4cc3ss}');
SQLEOF
echo -e "${GREEN}[+] Database '$DB_NAME' created and data imported.${NC}"

# -----------------------------------------------
# STEP 8: Fix database connection in all PHP files
# -----------------------------------------------
echo -e "${YELLOW}[*] Updating database credentials in PHP files...${NC}"

# Fix include/config.php
sudo bash -c "cat > $WEB_DIR/include/config.php" <<EOF
<?php
define('DB_SERVER','localhost');
define('DB_USER','$DB_USER');
define('DB_PASS','$DB_PASS');
define('DB_NAME','$DB_NAME');
\$con = mysqli_connect(DB_SERVER,DB_USER,DB_PASS,DB_NAME);
if (mysqli_connect_errno())
{
 echo "Failed to connect to MySQL: " . mysqli_connect_error();
}
?>
EOF

# Fix all hardcoded mysqli_connect calls
sudo grep -rl 'mysqli_connect("localhost","root"' "$WEB_DIR"/ | while read file; do
    sudo sed -i "s/mysqli_connect(\"localhost\",\"root\",\"\"/mysqli_connect(\"localhost\",\"$DB_USER\",\"$DB_PASS\"/g" "$file"
    sudo sed -i "s/mysqli_connect(\"localhost\",\"root\",\"\",$DB_NAME/mysqli_connect(\"localhost\",\"$DB_USER\",\"$DB_PASS\",\"$DB_NAME\"/g" "$file"
done

echo -e "${GREEN}[+] Database credentials updated.${NC}"

# -----------------------------------------------
# STEP 9: Set permissions
# -----------------------------------------------
echo -e "${YELLOW}[*] Setting file permissions...${NC}"
sudo chown -R www-data:www-data "$WEB_DIR"
sudo chmod -R 755 "$WEB_DIR"
echo -e "${GREEN}[+] Permissions set.${NC}"

# -----------------------------------------------
# STEP 10: Restart Apache
# -----------------------------------------------
echo -e "${YELLOW}[*] Restarting Apache2...${NC}"
sudo systemctl restart apache2
echo -e "${GREEN}[+] Apache2 restarted.${NC}"

# -----------------------------------------------
# DONE - Show access URL
# -----------------------------------------------
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}======================================================"
echo "   ✅  SETUP COMPLETE!"
echo "======================================================"
echo -e "${NC}"
echo -e "🌐 Access the web application at:"
echo -e "${BLUE}   http://$IP/hospital${NC}"
echo -e "${BLUE}   http://127.0.0.1/hospital${NC}"
echo ""
echo -e "🔑 Database Info:"
echo -e "   DB Name : $DB_NAME"
echo -e "   DB User : $DB_USER"
echo -e "   DB Pass : $DB_PASS"
echo ""
echo -e "👤 Register a new account at: http://$IP/hospital"
echo -e "${GREEN}======================================================"
echo -e "${NC}"
