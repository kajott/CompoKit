#!/bin/bash
if [ "$1" == "-h" -o "$1" == "--help" ] ; then cat <<EOF
Usage: $0 [-r|--reconfigure]

This script sets up a Wuhu server on a stock Debian installation, with a few
CompoKit-specific additions like an SSH reverse proxy.

The script is idempotent: For every operation it performs, it first checks
whether this operation has already been performed earlier. This means that
it should be safe to run again and again without bad effects, and when it
fails at some point, it should be able to continue from there next time.

EOF
exit 0 ; fi

###############################################################################
## MARK: helpers
###############################################################################

set -o pipefail
umask 002

function check_start {
    echo -ne "\x1b[33mChecking for $1 ... \x1b[0m"
}

function check_ok {
    echo -e "\x1b[32m${1:-Success}\x1b[0m"
}

function check_fail {
    echo -e "\x1b[31m${1:-Failed}\x1b[0m"
}

function show_error {
    echo -e "\x1b[1;31m$1:\x1b[22m $2\x1b[0m"
}

function wait_for_user {
    echo -ne "\x1b[2m[Enter = continue; Ctrl+C = exit]\x1b[0m "
    read
    echo
}

function confirm {
    echo "Will now $1."
    wait_for_user
}

function run_cmd {
    ( set -ex ; "$@" ) || exit 1
}

###############################################################################
## MARK: prerequisites
###############################################################################

check_start "distribution family"
if which apt >/dev/null ; then
    check_ok "Debian or derived"
else
    check_fail Non-Debian
    show_error FATAL "unsupported distribution family"
    echo "This script is only meant for Debian-style GNU/Linux distributions. Exiting."
    exit 1
fi

check_start "distribution version"
if [ $(lsb_release -cs 2>/dev/null) == "bookworm" ] ; then
    check_ok "$(lsb_release -ds 2>/dev/null)"
else
    check_fail "$(lsb_release -ds 2>/dev/null)"
    show_error WARNING "unsupported distribution version"
    echo "This script is meant for Debian GNU/Linux 12 (bookworm)."
    echo "It *may* work on other distributions or versions, but this isn't guaranteed."
    wait_for_user
fi

###############################################################################
## MARK: config
###############################################################################

cfgfile="$(dirname "$0")/wuhu_setup.conf"
if [ "$1" == "-r" -o "$1" == "--reconfigure" ] ; then
    cfg_ok=""
else
    check_start "wuhu_setup configuration"
    if [ -f "$cfgfile" ] ; then
        source "$cfgfile"
    fi
    cfg_ok="OK"
    [ -z "$WUHU_DIR"     ] && cfg_ok=""
    [ -z "$WUHU_REPO"    ] && cfg_ok=""
    [ -z "$PARTY_ADDR"   ] && cfg_ok=""
    [ -z "$ADMIN_ADDR"   ] && cfg_ok=""
    [ -z "$ADMIN_PORT"   ] && cfg_ok=""
    [ -z "$UPLOAD_LIMIT" ] && cfg_ok=""
    if [ -n "$PROXY_SERVER" ] ; then
        [ -z "$PROXY_USER"      ] && cfg_ok=""
        [ -z "$PROXY_HTTP_PORT" ] && cfg_ok=""
        [ -z "$PROXY_SSH_PORT"  ] && cfg_ok=""
    fi
    if [ -n "$cfg_ok" ] ; then
        check_ok
    else
        check_fail
    fi
fi

# start interactive configuration
if [ -z "$cfg_ok" ] ; then
    check_start "whiptail installation"
    if which whiptail >&/dev/null ; then
        check_ok
    else
        check_fail
        confirm "install the whiptail package (used for the configuation wizard)"
        run_cmd sudo apt -y install whiptail
    fi

    echo "Running interactive configuration wizard ..."
    whiptail --backtitle "Wuhu Setup" --title "Welcome" --yes-button OK --no-button Cancel --yesno "\
This script will install Wuhu and all prerequisites on this machine.\n\n\
Some system files will be modified under the assumption that being the Wuhu \
server is this machine's sole purpose.\n\n\
The script can be re-run at any time to repair the installation (e.g. if \
packages have been uninstalled, important configuration files have been changed, \
or file permissions have been set incorrectly." 16 70
    if [ $? != 0 ] ; then echo "Aborted by user." ; exit 3 ; fi

    WUHU_DIR="$(whiptail --backtitle "Wuhu Setup" --title "Installation Directory" --inputbox "\n\
Please enter the full path to the directory where Wuhu and its working data \
(releases, screenshots) shall be installed to:" 10 70 \
"${WUHU_DIR:-/srv/wuhu}" 3>&1 1>&2 2>&3)"
    if [ $? != 0 -o -z "$WUHU_DIR" ] ; then echo "Aborted by user." ; exit 3 ; fi

    WUHU_REPO="$(whiptail --backtitle "Wuhu Setup" --title "Wuhu Repository" --inputbox "\n\
Please enter the URL of the Git repository from which Wuhu shall be fetched:" 10 70 \
"${WUHU_REPO:-https://github.com/kajott/wuhu}" 3>&1 1>&2 2>&3)"
    if [ $? != 0 -o -z "$WUHU_REPO" ] ; then echo "Aborted by user." ; exit 3 ; fi

    PARTY_ADDR="$(whiptail --backtitle "Wuhu Setup" --title "Visitor Website URL" --inputbox "\n\
Please enter the public URL under which the visitor website shall be reachable:" 10 70 \
"${PARTY_ADDR:-www.party}" 3>&1 1>&2 2>&3)"
    if [ $? != 0 -o -z "$PARTY_ADDR" ] ; then echo "Aborted by user." ; exit 3 ; fi

    ADMIN_ADDR="$(whiptail --backtitle "Wuhu Setup" --title "Admin Interface URL" --inputbox "\n\
Please enter the public URL under which the Wuhu administration interface shall be reachable:" 10 70 \
"${ADMIN_ADDR:-admin.party}" 3>&1 1>&2 2>&3)"
    if [ $? != 0 -o -z "$ADMIN_ADDR" ] ; then echo "Aborted by user." ; exit 3 ; fi

    ADMIN_PORT="$(whiptail --backtitle "Wuhu Setup" --title "Admin Port" --inputbox "\n\
Please enter the port number under which the Wuhu administration interface shall be reachable \
in case hostname-based routing fails:" 10    70 \
"${ADMIN_PORT:-1337}" 3>&1 1>&2 2>&3)"
    if [ $? != 0 -o -z "$ADMIN_PORT" ] ; then echo "Aborted by user." ; exit 3 ; fi
    check_start "valid admin port number"
    if [[ "$ADMIN_PORT" =~ ^[0-9]+$ ]] ; then
        check_ok
    else
        check_fail
        show_error FATAL "admin port number is not valid"
        exit 2
    fi

    UPLOAD_LIMIT="$(whiptail --backtitle "Wuhu Setup" --title "Upload Size Limit" --inputbox "\n\
Please enter the maximum size of entry uploads via the visitor website \
('M' suffix = megabytes, 'G' suffix = gigabytes):" 10 70 \
"${UPLOAD_LIMIT:-200M}" 3>&1 1>&2 2>&3)"
    if [ $? != 0 -o -z "$UPLOAD_LIMIT" ] ; then echo "Aborted by user." ; exit 3 ; fi
    check_start "valid upload size limit"
    if [[ "$UPLOAD_LIMIT" =~ ^[0-9]+[MG]$ ]] ; then
        check_ok
    else
        check_fail
        show_error FATAL "upload size limit is not valid"
        exit 2
    fi

    PROXY_SERVER="$(whiptail --backtitle "Wuhu Setup" --title "Proxy Server IP Address" --inputbox "\n\
Please enter the IP address of the proxy server.\n\n\
The proxy server can be any machine reachable via the Internet that runs an \
OpenSSH server and an Apache server (or any other webserver with reverse proxy \
functionality, but this needs to be configured manually then). The Wuhu server \
will then be configured to maintain a permanent SSH port-forwarding connection \
to the proxy server, similar to a simple VPN, over which requests to the visitor \
and admin websites will be forwarded. This way, the Wuhu server is reachable via \
a fixed address and URL, regardless of its physical location.\n\n\
Leave this field empty if you don't want or need proxy functionality." 22 70 \
"${PROXY_SERVER}" 3>&1 1>&2 2>&3)"
    if [ $? != 0 ] ; then echo "Aborted by user." ; exit 3 ; fi

    if [ -n "$PROXY_SERVER" ] ; then
        check_start "valid proxy IP address"
        if [[ "$PROXY_SERVER" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
            check_ok
        else
            check_fail
            show_error FATAL "proxy server IP address is not valid"
            exit 2
        fi

        PROXY_USER="$(whiptail --backtitle "Wuhu Setup" --title "Proxy User Name" --inputbox "\n\
Please enter the user name on the proxy server that shall be used for the SSH connection \
between the Wuhu server and the proxy.\n\n\
Note: This user does not need (and, for security reasons, should not have) a working \
login shell; it's only used as an endpoint for SSH port forwarding." 14 70 \
"${PROXY_USER:-wuhuproxy}" 3>&1 1>&2 2>&3)"
        if [ $? != 0 -o -z "$PROXY_USER" ] ; then echo "Aborted by user." ; exit 3 ; fi

        PROXY_HTTP_PORT="$(whiptail --backtitle "Wuhu Setup" --title "Proxy Internal HTTP Port" --inputbox "\n\
Please enter the port number under which the Wuhu server's web server be accessible at the proxy server's side:" 10 70 \
"${PROXY_HTTP_PORT:-6502}" 3>&1 1>&2 2>&3)"
        if [ $? != 0 -o -z "$PROXY_HTTP_PORT" ] ; then echo "Aborted by user." ; exit 3 ; fi
        check_start "valid proxy HTTP port"
        if [[ "$PROXY_HTTP_PORT" =~ ^[0-9]+$ ]] ; then
            check_ok
        else
            check_fail
            show_error FATAL "proxy server HTTP port is not valid"
            exit 2
        fi

        PROXY_SSH_PORT="$(whiptail --backtitle "Wuhu Setup" --title "Proxy Internal SSH Port" --inputbox "\n\
Please enter the port number under which the Wuhu server's SSH server be accessible at the proxy server's side:" 10 70 \
"${PROXY_SSH_PORT:-6522}" 3>&1 1>&2 2>&3)"
        if [ $? != 0 -o -z "$PROXY_SSH_PORT" ] ; then echo "Aborted by user." ; exit 3 ; fi
        check_start "valid proxy SSH port"
        if [[ "$PROXY_SSH_PORT" =~ ^[0-9]+$ ]] ; then
            check_ok
        else
            check_fail
            show_error FATAL "proxy server SSH port is not valid"
            exit 2
        fi
    fi

    echo "Installation wizard finished, saving configuration ..."
    cat >"$cfgfile" <<EOF
# wuhu_setup configuration file
WUHU_DIR=$WUHU_DIR
WUHU_REPO=$WUHU_REPO
PARTY_ADDR=$PARTY_ADDR
ADMIN_ADDR=$ADMIN_ADDR
ADMIN_PORT=$ADMIN_PORT
UPLOAD_LIMIT=$UPLOAD_LIMIT
PROXY_SERVER=$PROXY_SERVER
PROXY_USER=$PROXY_USER
PROXY_HTTP_PORT=$PROXY_HTTP_PORT
PROXY_SSH_PORT=$PROXY_SSH_PORT
EOF
fi

###############################################################################
## MARK: packages
###############################################################################

# final prerequisite check
check_start "sudo privileges"
if sudo true ; then
    check_ok
else
    check_fail
    show_error ERROR "sudo privileges are required"
    exit 1
fi

check_start "distribution's default PHP version"
PHP_VERSION=$(apt-cache search 'apache2-mod-php[0-9]' | tail -n 1 | sed -r 's/.*([0-9]+\.[0-9+]).*/\1/')
if [ -n "$PHP_VERSION" ] ; then
    check_ok $PHP_VERSION
else
    check_fail "Not Found"
    show_error FATAL "no Apache PHP module found in package lists"
    echo "You may need to run 'sudo apt update' first."
    exit 1
fi

packages=""

check_start "Apache installation"
if [ -x /usr/sbin/a2enmod ] ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages apache2"
fi

check_start "PHP installation"
if [ -f /usr/lib/apache2/modules/libphp$PHP_VERSION.so ] ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages php$PHP_VERSION libapache2-mod-php$PHP_VERSION"
fi

check_start "PHP GD module installation"
if [ -f /usr/lib/php/*/gd.so ] ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages php$PHP_VERSION-gd"
fi

check_start "PHP mbstring module installation"
if [ -f /usr/lib/php/*/mbstring.so ] ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages php$PHP_VERSION-mbstring"
fi

check_start "PHP curl module installation"
if [ -f /usr/lib/php/*/curl.so ] ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages php$PHP_VERSION-curl"
fi

check_start "PHP MySQL module installation"
if [ -f /usr/lib/php/*/mysqli.so ] ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages php$PHP_VERSION-mysql"
fi

check_start "MariaDB/MySQL installation"
if [ -x /usr/sbin/mariadbd ] ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages mariadb-server"
fi

check_start "SSH client and server installation"
if which ssh >/dev/null ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages ssh"
fi

check_start "Git installation"
if which git >/dev/null ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages git"
fi

check_start "UDisks installation"
if which udisksctl >/dev/null ; then
    check_ok
else
    check_fail "not installed"
    packages="$packages udisks2"
fi

if [ -n "$packages" ] ; then
    confirm "install the following package(s):$packages"
    run_cmd sudo apt -y install $packages
fi

###############################################################################
## MARK: directories
###############################################################################

check_start "$WUHU_DIR"
if [ -d $WUHU_DIR ] ; then
    check_ok
else
    check_fail
    confirm "create the directory $WUHU_DIR"
    run_cmd sudo mkdir -p $WUHU_DIR
fi

check_start "$WUHU_DIR ownership"
if [ "$(stat -c '%u:%G' $WUHU_DIR)" == "1000:www-data" ] ; then
    check_ok
else
    check_fail
    confirm "change owner of $WUHU_DIR to $USER:www-data"
    run_cmd sudo chown -R 1000:www-data $WUHU_DIR
fi

check_start "$WUHU_DIR permissions"
if [ "$(stat -c '%A' $WUHU_DIR)" == "drwxrwsr-x" ] ; then
    check_ok
else
    check_fail
    confirm "change permissions of $WUHU_DIR to 775 + setgid"
    run_cmd sudo chmod -R u+rwX,g+rwXs,o+rX $WUHU_DIR
fi

check_start "Wuhu checkout"
if [ -d $WUHU_DIR/www_party -a -d $WUHU_DIR/www_admin ] ; then
    check_ok
else
    check_fail
    confirm "check out $WUHU_REPO into $WUHU_DIR"
    run_cmd rm -rf $WUHU_DIR/tmp
    run_cmd git clone $WUHU_REPO $WUHU_DIR/tmp
    run_cmd mv $WUHU_DIR/tmp/* $WUHU_DIR/tmp/.* $WUHU_DIR/
    run_cmd rmdir $WUHU_DIR/tmp
fi

need_writable_subdirs="entries_private entries_public screenshots www_admin/slides www_admin/plugins/backup"

dirs=""
for subdir in $need_writable_subdirs ; do
    check_start "$WUHU_DIR/$subdir"
    if [ -d $WUHU_DIR/$subdir ] ; then
        check_ok
    else
        check_fail
        dirs="$dirs $WUHU_DIR/$subdir"
    fi
done
if [ -n "$dirs" ] ; then
    confirm "create directories:$dirs"
    run_cmd mkdir $dirs
fi

dirs=""
for subdir in $need_writable_subdirs ; do
    check_start "$WUHU_DIR/$subdir permissions"
    if [ "$(stat -c '%A' $WUHU_DIR/$subdir)" == "drwxrwsr-x" ] ; then
        check_ok
    else
        check_fail
        dirs="$dirs $WUHU_DIR/$subdir"
    fi
done
if [ -n "$dirs" ] ; then
    confirm "change permissions to 775 + setgid:$dirs"
    run_cmd sudo chmod -R u+rwX,g+rwXs,o+rX $dirs
fi

dirs=""
for subdir in $need_writable_subdirs ; do
    check_start "$WUHU_DIR/$subdir group ownership"
    if [ "$(stat -c '%G' $WUHU_DIR/$subdir)" == "www-data" ] ; then
        check_ok
    else
        check_fail
        dirs="$dirs $WUHU_DIR/$subdir"
    fi
done
if [ -n "$dirs" ] ; then
    confirm "change group ownership to www-data:$dirs"
    run_cmd sudo chown -R :www-data $dirs
fi

###############################################################################
## MARK: database
###############################################################################

check_start "database"
if true | sudo mysql wuhu 2>/dev/null ; then
    check_ok
else
    check_fail
    confirm "create 'wuhu' database and database user"
    if [ -f .wuhudbpasswd ] ; then
        echo "reading password from .wuhudbpasswd"
        pwd="$(cat .wuhudbpasswd)"
    else
        echo "creating a new password in .wuhudbpasswd"
        pwd="$(base64 </dev/random | head -n 1 | cut -b-22)"
        echo -e "the newly-created password is: \x1b[1m$pwd\x1b[0m"
        echo "$pwd" >.wuhudbpasswd
    fi
    echo -e "CREATE DATABASE wuhu;\n" \
            "GRANT ALL PRIVILEGES ON wuhu.* TO 'wuhu'@'localhost' IDENTIFIED BY '$pwd';\n" \
         | sudo mysql
fi

###############################################################################
## MARK: PHP config
###############################################################################

apache_needs_restart=""

for cfgfile in /etc/php/8.2/*/php.ini ; do
    changes=""
    TZ=$(cat /etc/timezone)
    [ -z "$TZ" ] && TZ="UTC"
    for cfg in \
        upload_max_filesize=$UPLOAD_LIMIT \
        post_max_size=$UPLOAD_LIMIT \
        memory_limit=512M \
        session.gc_maxlifetime=604800 \
        short_open_tag=On \
        date.timezone=$TZ
    do
        key=${cfg%%=*}
        value=${cfg##*=}
        check_start "$key in $cfgfile"
        oldval="$(grep "^$key" $cfgfile | cut -d= -f2-)"
        if [ -z "$oldval" ] ; then
            check_fail
            changes="$changes;s:^;?\s*($key).*$:\\1 = $value:"
        elif [ $oldval == $value ] ; then
            check_ok
        else
            check_fail
            changes="$changes;s:^($key).*$:\\1 = $value:"
        fi
    done
    if [ -n "$changes" ] ; then
        confirm "apply regex '${changes:1}' to $cfgfile"
        run_cmd sudo sed -i -r -e "${changes:1}" $cfgfile
        apache_needs_restart="yes"
    fi
done

###############################################################################
## MARK: Apache config
###############################################################################

check_start "admin port in Apache"
if grep -i "^listen $ADMIN_PORT$" /etc/apache2/ports.conf >/dev/null ; then
    check_ok
else
    check_fail
    confirm "add 'Listen $ADMIN_PORT' to /etc/apache2/ports.conf"
    sudo tee -a /etc/apache2/ports.conf <<EOF

Listen $ADMIN_PORT
EOF
    apache_needs_restart="absolutely"
fi

check_start "Apache SSL module status"
need_mods=""
for check_mod in ssl authz_groupfile remoteip headers ; do
    if [ ! -L /etc/apache2/mods-enabled/$check_mod.load ] ; then
        need_mods="$need_mods $check_mod"
    fi
done
if [ -z "$need_mods" ] ; then
    check_ok
else
    check_fail
    confirm "enable the following Apache module(s):$need_mods"
    for mod in $need_mods ; do
        run_cmd sudo a2enmod $mod
    done
    apache_needs_restart="definitely"
fi

check_start "$WUHU_DIR/wuhu/ssl_cert.{key,crt}"
if [ -f $WUHU_DIR/ssl_cert.crt -a -f $WUHU_DIR/ssl_cert.key ] ; then
    check_ok
else
    check_fail
    confirm "create a simple self-signed SSL certificate as a fallback"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $WUHU_DIR/ssl_cert.key -out $WUHU_DIR/ssl_cert.crt
fi

check_start "$WUHU_DIR/wuhu/ssl_cert.key permissions"
if [ "$(stat -c '%A' $WUHU_DIR/ssl_cert.key)" == "-rw-r-----" ] ; then
    check_ok
else
    check_fail
    confirm "set $WUHU_DIR/ssl_cert.key permissions to 640"
    run_cmd chmod 640 $WUHU_DIR/ssl_cert.key
fi

sitefile=/etc/apache2/sites-available/wuhu.conf
check_start "$sitefile"
if [ $sitefile -nt "$0" ] ; then
    changed=""
else
    if [ -n "$PROXY_SERVER" ] ; then
        proxy_server_auth="RemoteIPInternalProxy $PROXY_SERVER/32"
    else
        proxy_server_auth="# RemoteIPInternalProxy <serverIP>/32"
    fi
    cat >/tmp/wuhu.site <<EOF
# unencrypted HTTP, any Host -> Wuhu visitor site
<VirtualHost *:80>
    UseCanonicalName Off
    DocumentRoot $WUHU_DIR/www_party
    <Directory $WUHU_DIR/www_party>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    RemoteIPHeader X-Forwarded-For
    $proxy_server_auth
    RemoteIPInternalProxy 127.0.0.1/8
    RemoteIPInternalProxy ::1
    CustomLog \${APACHE_LOG_DIR}/party_access.log combined
    ErrorLog  \${APACHE_LOG_DIR}/party_error.log
</VirtualHost>

# HTTPS, visitor site Host -> Wuhu visitor site
<VirtualHost *:443>
    ServerName $PARTY_ADDR
    UseCanonicalName Off
    DocumentRoot $WUHU_DIR/www_party
    <Directory $WUHU_DIR/www_party>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    RemoteIPHeader X-Forwarded-For
    $proxy_server_auth
    RemoteIPInternalProxy 127.0.0.1/8
    RemoteIPInternalProxy ::1
    CustomLog \${APACHE_LOG_DIR}/party_access.log combined
    ErrorLog  \${APACHE_LOG_DIR}/party_error.log
    SSLEngine on
    SSLCertificateFile    $WUHU_DIR/ssl_cert.crt
    SSLCertificateKeyFile $WUHU_DIR/ssl_cert.key
</VirtualHost>

# unencrypted HTTP, admin site Host -> Wuhu admin site
<VirtualHost *:80>
    ServerName $ADMIN_ADDR
    UseCanonicalName Off
    DocumentRoot $WUHU_DIR/www_admin
    <Directory $WUHU_DIR/www_admin>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    RemoteIPHeader X-Forwarded-For
    $proxy_server_auth
    RemoteIPInternalProxy 127.0.0.1/8
    RemoteIPInternalProxy ::1
    CustomLog \${APACHE_LOG_DIR}/admin_access.log combined
    ErrorLog  \${APACHE_LOG_DIR}/admin_error.log
</VirtualHost>

# HTTPS, admin site Host -> Wuhu admin site
<VirtualHost *:443>
    ServerName $ADMIN_ADDR
    UseCanonicalName Off
    DocumentRoot $WUHU_DIR/www_admin
    <Directory $WUHU_DIR/www_admin>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    CustomLog \${APACHE_LOG_DIR}/admin_access.log combined
    ErrorLog  \${APACHE_LOG_DIR}/admin_error.log
    RemoteIPHeader X-Forwarded-For
    $proxy_server_auth
    RemoteIPInternalProxy 127.0.0.1/8
    RemoteIPInternalProxy ::1
    SSLEngine on
    SSLCertificateFile    $WUHU_DIR/ssl_cert.crt
    SSLCertificateKeyFile $WUHU_DIR/ssl_cert.key
</VirtualHost>

# unencrypted HTTP on port $ADMIN_PORT -> Wuhu admin site
# (useful if DNS isn't configured to route $ADMIN_ADDR to this host)
<VirtualHost *:$ADMIN_PORT>
    UseCanonicalName Off
    DocumentRoot $WUHU_DIR/www_admin
    <Directory $WUHU_DIR/www_admin>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    CustomLog \${APACHE_LOG_DIR}/admin_access.log combined
    ErrorLog  \${APACHE_LOG_DIR}/admin_error.log
</VirtualHost>
EOF
    if diff /tmp/wuhu.site $sitefile >&/dev/null ; then
        changed=""
    else
        changed="yes"
    fi
fi
if [ -z "$changed" ] ; then
    check_ok
else
    check_fail "non-existing or too old"
    confirm "install/update $sitefile"
    sudo tee $sitefile </tmp/wuhu.site
    apache_needs_restart="certainly"
fi
rm -f /tmp/wuhu.site

check_start "enable status of the 'wuhu' Apache site"
if [ -L /etc/apache2/sites-enabled/wuhu.conf ] ; then
    check_ok
else
    check_fail
    confirm "enable the 'wuhu' site"
    run_cmd sudo a2ensite wuhu
    apache_needs_restart="sure"
fi

check_start "any other interfering Apache sites"
other_sites=""
for f in /etc/apache2/sites-enabled/*.conf ; do
    site=$(basename ${f%.conf})
    if [ "$site" != "wuhu" ] ; then
        other_sites="$other_sites $site"
    fi
done
if [ -z "$other_sites" ] ; then
    check_ok
else
    check_fail
    confirm "disable the following Apache site(s):$other_sites"
    for site in $other_sites ; do
        run_cmd sudo a2dissite $site
    done
    apache_needs_restart="totally"
fi

if [ -n "$apache_needs_restart" ] ; then
    confirm "restart Apache"
    fail=""
    if sudo systemctl restart apache2.service ; then
        sleep 1
    else
        fail="yes"
    fi
    if sudo systemctl --no-pager status apache2.service ; then
        true
    else
        fail="yes"
    fi
    if [ -n "$fail" ] ; then
        show_error ERROR "Apache failed to restart"
        exit 1
    fi
fi

template="$WUHU_DIR/www_party/template.html"
check_start "$template"
if [ -f "$template" ] ; then
    check_ok
else
    check_fail
    confirm "install $template from CompoKit default"
    # compressed dump follows; to produce a new one, use:
    #   gzip -9 < www_party/template.html | base64
    base64 -d <<EOF | gunzip > "$template"
H4sIABgsx2gCA4VXYW/bNhD97l/B2sjQbpYt2XFmyE6wIvWwYWhadCmGYigMWjpZXChRJSk7btH/
viMpRbJrO/lgx+S74927xyM5f/Hm3e39p/cLkuqM33Tm9mueAo3xh2aaw82ndx8/LN+//nD/aXn3
+u1i+cfiw2I+dHOdeQaakiilUoG+7pY68abdejinGVx3Nwy2hZC6SyKRa8gRtmWxTq9j2LAIPPuj
T1jONKPcUxHlcB0MfONG6R0HoncF+tHwqIeRUjje+Zl8Iwl68xKaMb4Lu3/DWgD5+Ge3r2iuPAWS
JTPyvbMS8Q6xGZVrlof+jKxo9LCWoszjsHd5eTnDoLiQYQ8ADJ4iuBqJp9MZMYt6MURCUs1EHuYi
t7hOz3AEEuFtj1ej0YwUNI5Zvg4HE8iIT+xXAJkxq63SoE5gC2yd6nDsY2xNlHZKsa8QBhP/wlpm
kJcHqwVB0EyVfC/POgh/D8EZgmKmCk53Ics5y8FbcRE9nI+6ZZ7KloeaDQdocWfZbOc38VuBDFAE
cpcAxCabZabWNRs25anJuG2cC5lR/lSqJEn26ighboU/MjGvhESaPUljViqbkitapUDL1KNTXhj4
vl88Nh7qpBMhtCuwc6ZFEQbFI1GCs5j0pkYeJ2wUhstbPFUU/7hmk/SvE0xaFDRieodJTGy8LC9K
/a+VvxHi535roKBKbTGyz30zRSXQvgIOkUmuDmuC4U7NOhnLq5XHV3bh723fqlxlTH/eKwJGeNG2
C3yT4j7LTm2OGMt6S5vReFwXbJsyDXVN7B48Wp06DVMc9Jq62qP+XbycruAop1bxJiBiJdZx6uJM
6RY64WDoxk9vK2kRmg+DduDWznkSvvFWUTaqQqjAg0hkhTgv2Suj90qvVimN9Z74G3lxSHQ4bfSV
mOZU8e0mHVFuUdMXQ6YpZ9EPvpWmulQHvcIGsVeP422gVVNX5Oc31hkaxm7bHwlv+aXE4BMG8UGg
l9PLUyYY8SmrqWm8jdUGtyF52g6Nikd+VcpeWXCBrThOGAdFWJ8cjNAnTTjyg7qFcLYB4/4W06RI
nCQ9q4cFrszA0G6kV1XINci9Kro++JyXdHzmgAjaPfqUP8vBuXDCZywdiaeOi1anGE0Oqh7YWBvS
ba9otrT9bX21B+xJi8Vd52GEVQTZnIfkEreFbzKNSqlQwYVgDnFe4QdiHVVN+nzGAyebHxRmG9rz
1kZDSC4a05xl9tLgxWV1e/AHEzVrTZgLEjYylj+0RzF2h/ciXFoj8Ym5HEEbo1lmFJWUeWQ9A1X2
JP7tAXaJRLeKWL8Yh3+BH/XJYi4MZLI3hEGZQdPwD4Godx33dYrjrfIYGdvNhkHgNW/FwfzTHDue
tFWt+3oDW8IGK2uOnANxX1Vt4ghymRmSN+7QrhrqFYWTcAc1f0/waJqchMd4HzNSbMHBFfoo3HX+
Pe9jOA1XgFWisg2HM/AYMqFSsW3Bp1FwEm6USCNN9uCnmYn/wyv6fuwjx0ynt2GKaSEV0XGY69SL
Usbjl6NXJ+qkyigCdXjEjK5GzZmXHN6OquN/1JxwfuS8JZTxUkJ/AFKKozfq+uI3fd5p5ELszIe2
5d3Mh/YxMzcPAXxQxGxDWHzddffwLj51ghMPHJyYDxHeMjKXV3x9fLt4u7j7ePG9czhf3S7Nw+WF
5xE8taSuHz3E84zl7bu7+8XdvTE2EMjjPYDz+OTQXScxSnuhvJlTvH5DgtFrXYTD4bZMy0HdAgZp
Oeze/IND8yG9IS9vjVT/YppAzMz8K/JTJIrdjPxeGZBfyJta/UKusbd8RV6RN7dWldvQEod02Pfh
/8ZEpvwwDgAA
EOF
fi

template="$WUHU_DIR/www_admin/slideviewer/custom.css"
check_start "$template"
if [ -f "$template" ] ; then
    check_ok
else
    check_fail
    confirm "install $template from CompoKit default"
    # compressed dump follows; to produce a new one, use:
    #   gzip -9 < www_admin/slideviewer/custom.css | base64
    base64 -d <<EOF | gunzip > "$template"
H4sIAEosx2gCA81XWW/jNhB+96+YugiQBLEie+McNlCgQBdo0eMh3UVfFggoibLYSKRAUj66yH/v
DCnZkq9sAweogiQSybmH30deX0JZWVipSoNaSDB2lQs5g58/Pn6Ey+teL9B8zlkOgclFwg38AIbH
VigZaGUZvfxJE4HlS3t1ZDWTUlUy5gWX1kkcWxzjUpugP9+wsijVT8KUOVu9urjU4h8+E3MMsFmb
VEWx6n3tAVxfQsTi55lG28kEvk/TdEoZeOn1IpWsrqDWO5gLviiVto1UwlNW5RZSJS3EKleaxMC/
1oros9KGvqWSfEpaD/oJJZDqkiUJejrIeWonMA7L5bQ1qsUsaw1j0fgg435wOBqfORPXl6d8vvR+
//Hx1wk4f6Epf+/LSY1Qy1lRcMuinLs8FEzPhJxACPcYbP2PYqaWG7BczHCSkuSzuhG2yVXnM+uk
NVLWqmICwYe7MS92ZDPOEqgrnFG8OAL9T7igD9fQ/zjHPu4DreIac7HwNU98J7arvNZJLx0P6hIG
u+afOKm3q9ILUGcNDPbuBGM/W4duNZMmVRqDqMqS65gZ3moR1DzkhVO/eaP5SGl0eqBZIiqD3eLN
77UeUBNL58Sx0DYST25DAj1fu/spZOEU9pt5MrwQkuldIXZ/WCjB3FPb7wqFh4UKhhL0tS00uo8P
CnmBPTHdhPER9wplMmyMbaHx3WH3coGQENtdS8fcS/42/Jh774UDvtQevXqD0z69z4ZoiEEqljwB
bDyFNLUQuIkzppNBqYwg9MG5SC0RPbFLGcyFthVC6vBhFC6H4X0IJtacy6D3KRMGxfMcIs3ZM4iU
OA8ocbSxJULZnNfIRjsNhHQTf1VZBZ9/AauAyZXNyCmeG/7dyQN+xH6ZE8ygo1hZofmaD2pnFwy7
EB2pDMdYjWUywVQ4FwfE2xySlWSFiHs+XcE7QPO3E3GAQegVIYi0tOm0x766bhNgkVF5ZR1iWVUi
vjsec2TnXhF4qQItBTx3xwcoKmMh4r56CtIKyyoVQUhel9Az4RVqgUtQqEYvhPEYrvlvLjvnFygo
6wQbHG5coxLTQrJL1qjpsBscvq8ZNvQk9PKmlMiqiP57PhYisRmZ9hSw7UqXDx23TLvcMRyF9Ups
NJ3majEhaku4nLaOK4SejTKTsYRWDW+ReN2fKEeAcSpKFguLdBAG47fmwQpbc/yRNKyd9qkYNp91
OmKWx+fDBxqFgZ+96KTn5mDMb3OaVTZTrxbvw83/y2scsHRUeM3vm9v9frd5Rc8idj68vb8K8Se4
G1+02meRCds9hIRYQXdsGzWqusePh4eHZny5brgblKBfZyr0hsjOyxshqHC48Urs4/HRmm22T1Ml
X0W3/7CKTvzilEVzFP8HK1qnwEVt+tbv0mbTJns27ZEcvtOBoHW/ao4Fp2eg7Uvc3jTVgDf0UNnJ
3B2l6qVWhJRh683srxnde9XWsly0V64vEPWxunXsHtGZO1y/7CgKhEwVXiiZfKZc7VQ3UnmyU979
OjYY2tEwPizhAWwyiTgCghetqW7Sj1bQ30J3vB4d0lQqIa3Zczvw92Jh6qsU0ivSdMGeOdQic2EE
zbEZa6i1Vbe78dmWEyPnw0EXNsFsQjnvuwPzYRGWWiLhjcSFk/gXyceCvRIRAAA=
EOF
fi

###############################################################################
## MARK: backup
###############################################################################

check_start "safe access to NTFS volumes"
if grep -E '^blacklist ntfs3' /etc/modprobe.d/blacklist-ntfs3.conf >&/dev/null ; then
    check_ok
else
    check_fail
    confirm "blacklist the ntfs3 module to avoid clobbering NTFS volumes during backup"
    sudo tee /etc/modprobe.d/blacklist-ntfs3.conf <<EOF
# The ntfs3 module is fast, but it has a tendency to data corruption. To avoid
# that, blacklist the kernel module and force to use the slower, but more
# reliable userspace implementation ntfs-3g (note the 'g'!) instead.
blacklist ntfs3
EOF
fi

policyfile=/etc/polkit-1/rules.d/10-udisks.rules
check_start "$policyfile"
if [ $policyfile -nt "$0" ] ; then
    changed=""
else
    cat >/tmp/wuhu_backup.policy <<EOF
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.udisks2.filesystem-mount-other-seat") {
        return polkit.Result.YES;
    }
});
EOF
    if sudo diff /tmp/wuhu_backup.policy $policyfile >&/dev/null ; then
        changed=""
    else
        changed="yes"
    fi
fi
if [ -z "$changed" ] ; then
    check_ok
else
    check_fail "non-existing or too old"
    confirm "install/update $policyfile"
    sudo tee $policyfile </tmp/wuhu_backup.policy
fi
rm -f /tmp/wuhu_backup.policy

###############################################################################
## MARK: SSH proxy tunnel
###############################################################################

if [ -n "$PROXY_SERVER" ] ; then
# skip the entire block below if PROXY_SERVER is not set

unitfile=/etc/systemd/system/wuhu_tunnel.service
check_start "$unitfile"
if [ $unitfile -nt "$0" ] ; then
    changed=""
else
    cat >/tmp/wuhu_tunnel.service <<EOF
[Unit]
Description=SSH tunnel to Wuhu proxy server ($PROXY_SERVER)
After=network-online.target
ConditionPathExists=$WUHU_DIR/${PROXY_USER}_key

[Service]
User=$USER
ExecStart=/usr/bin/ssh -NT -o ServerAliveInterval=15 -o ExitOnForwardFailure=yes -i $WUHU_DIR/${PROXY_USER}_key -R $PROXY_HTTP_PORT:localhost:80 -R $PROXY_SSH_PORT:localhost:22 $PROXY_USER@$PROXY_SERVER
RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    if diff /tmp/wuhu_tunnel.service $unitfile >&/dev/null ; then
        changed=""
    else
        changed="yes"
    fi
fi
if [ -z "$changed" ] ; then
    check_ok
else
    check_fail "non-existing or too old"
    confirm "install/update $unitfile"
    sudo tee $unitfile </tmp/wuhu_tunnel.service
fi
rm -f /tmp/wuhu_tunnel.service

check_start "wuhu_tunnel.service status"
if systemctl is-enabled wuhu_tunnel.service >&/dev/null ; then
    check_ok
else
    check_fail
    confirm "enable wuhu_tunnel.service"
    sudo systemctl enable wuhu_tunnel.service
fi

cat >"$(dirname "$0")"/wuhu-proxy.conf <<EOF
<VirtualHost *:80>
    ServerName $PARTY_ADDR
    # Let the ACME challenge through if you want to use Let's Encrypt for TLS.
    # Change the path at the end of the "Alias" line to fit your configuration!
    ProxyPass /.well-known/acme-challenge !
    Alias /.well-known/acme-challenge/ "/var/www/html/.well-known/acme-challenge/"
    ProxyPass        / http://localhost:$PROXY_HTTP_PORT/ nocanon
    ProxyPassReverse / http://localhost:$PROXY_HTTP_PORT/
    ProxyPreserveHost On
    <Proxy *>
        Allow from all
    </Proxy>
</VirtualHost>

<VirtualHost *:443>
    ServerName $PARTY_ADDR
    ProxyPass        / http://localhost:$PROXY_HTTP_PORT/ nocanon
    ProxyPassReverse / http://localhost:$PROXY_HTTP_PORT/
    ProxyPreserveHost On
    <Proxy *>
        Allow from all
    </Proxy>
    SSLEngine on
    # Adapt these filenames to match your configuration.
    # If you don't want or need SSL, remove the entire <VirtualHost> block.
    SSLCertificateFile    /etc/ssl/wuhuproxy.crt
    SSLCertificateKeyFile /etc/ssl/wuhuproxy.key
</VirtualHost>

<VirtualHost *:80>
    ServerName $ADMIN_ADDR
    # Let the ACME challenge through if you want to use Let's Encrypt for TLS.
    # Change the path at the end of the "Alias" line to fit your configuration!
    ProxyPass /.well-known/acme-challenge !
    Alias /.well-known/acme-challenge/ "/var/www/html/.well-known/acme-challenge/"
    ProxyPass        / http://localhost:$PROXY_HTTP_PORT/ nocanon
    ProxyPassReverse / http://localhost:$PROXY_HTTP_PORT/
    ProxyPreserveHost On
    <Proxy *>
        Allow from all
    </Proxy>
</VirtualHost>

<VirtualHost *:443>
    ServerName $ADMIN_ADDR
    ProxyPass        / http://localhost:$PROXY_HTTP_PORT/ nocanon
    ProxyPassReverse / http://localhost:$PROXY_HTTP_PORT/
    ProxyPreserveHost On
    <Proxy *>
        Allow from all
    </Proxy>
    SSLEngine on
    # Adapt these filenames to match your configuration.
    # If you don't want or need SSL, remove the entire <VirtualHost> block.
    SSLCertificateFile    /etc/ssl/wuhuproxy.crt
    SSLCertificateKeyFile /etc/ssl/wuhuproxy.key
</VirtualHost>
EOF

fi  # skip the entire block above if PROXY_SERVER is not set

###############################################################################
## MARK: done
###############################################################################

echo -e "\x1b[32mDone.\x1b[0m"

HOST=$(hostname)
DBPASSWD=$(cat .wuhudbpasswd 2>/dev/null)
NOTES="$(dirname "$0")/wuhu_setup.notes.txt"
cat >$NOTES <<EOF
Wuhu setup is complete.

Things to do now:
- open http://$HOST:$ADMIN_PORT to get to the admin interface
- if it's the first time opening the admin interface, enter the following data:
  - party name:              your choice
  - partynet interface path: $WUHU_DIR/www_party
  - compo entry path:        $WUHU_DIR/entries_private
  - compo export path:       $WUHU_DIR/entries_public
  - screenshot path:         $WUHU_DIR/screenshots
  - screenshot size:         your choice; maybe increase it a _tiny_ bit
  - voting type:             your choice, but 'range' is req'd for live voting
  - party starting day:      your choice
  - MySQL database host:     localhost
  - MySQL database name:     wuhu
  - MySQL username:          wuhu
  - MySQL password:          ${DBPASSWD:-whatever you set up}
  - admin interface username and password: your choice
- probably change the template of the visitor website (www_party/template.html)
  such that it mentions the actual party name in the <title> and <h1> tags

EOF

if [ -n "PROXY_SERVER" ] ; then
cat >>$NOTES <<EOF
On the public proxy/relay server ($PROXY_SERVER):
- create a user for SSH forwarding:
    sudo adduser --disabled-login $PROXY_USER
- create an SSH key pair for that user, without a passphrase:
    sudo -u $PROXY_USER ssh-keygen
- turn this key into an authorized key:
    sudo -u $PROXY_USER cp /home/$PROXY_USER/.ssh/id_rsa.pub /home/$PROXY_USER/.ssh/authorized_keys2
- copy /home/$PROXY_USER/.ssh/id_rsa (the private key) onto *this* machine
  (the Wuhu server itself, *not* the proxy), as $WUHU_DIR/${PROXY_USER}_key
- copy wuhu-proxy.conf from *this* machine (the Wuhu server) onto the proxy
  server, edit it as needed and install it there as
    /etc/apache2/sites-available/wuhu-proxy.conf
- get an SSL certificate for the relevant websites
  ($PARTY_ADDR, $ADMIN_ADDR)
  and put the certificate and key file into the locations configured in
  wuhu-proxy.conf
  - if you don't want or need HTTPS, remove the two <VirtualHost *:443>
    blocks from wuhu-proxy.conf entirely
- enable the proxy site:
    sudo a2ensite wuhu-proxy.conf
    sudo systemctl restart apache2
Then on *this* machine (the Wuhu server itself):
- give the key file nice permissions:
    chmod 600 $WUHU_DIR/${PROXY_USER}_key
- make a test connection:
    ssh -i $WUHU_DIR/${PROXY_USER}_key $PROXY_USER@$PROXY_SERVER
  confirm the authenticity of the host; you should *not* be asked for a
  password, and the login should fail with a "This account is currently not
  available." message (this is fine, as it's only going to be used for the
  tunnel to the proxy anyway)
- start the tunnel service:
    sudo systemctl start wuhu_tunnel.service

If you want a development host to get direct SSH access to the Wuhu server
through the proxy, copy $WUHU_DIR/${PROXY_USER}_key from the Wuhu server
into ~/.ssh/${PROXY_USER}_key on the development host, and add the following
lines into ~/.ssh/config, so you can simply use 'ssh wuhu_remote':
    Host $PROXY_USER
        HostName $PROXY_SERVER
        User $PROXY_USER
        IdentityFile ~/.ssh/${PROXY_USER}_key
    Host wuhu_remote
        ProxyJump $PROXY_USER
        HostName localhost
        Port $PROXY_SSH_PORT
        User $USER

EOF
fi  # PROXY_SERVER defined

cat >>$NOTES <<EOF
Other things to consider configuring on the Wuhu server:
- add $USER to the www-data group to minimize permission issues during
  administration
- install the ifplugd package to ensure that the Ethernet connection is
  re-established when the cable is temporarily unplugged
EOF

cat $NOTES
echo
echo "A copy of this message has been stored in $NOTES for reference."
