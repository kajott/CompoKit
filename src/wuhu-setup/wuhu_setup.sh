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
H4sIAAAAAAACA5VXbW/bNhD+7l/BOsjQbpYt2XFmyI4xIM2AYVg7YC2KYSgCWjpZRChRIyk7bpH/
viMpRbRrO90Xv5B3x7vnHt4dF6/evr/98PefdyTXBV/2FvZrkQNN8Y9mmsPyU53Xi5H73VsUoClJ
cioV6Jt+rbNg1iejdqOkBdz0Nwy2lZC6TxJRaihRcMtSnd+ksGEJBPbPgLCSaUZ5oBLK4SYahs6Q
0jsORO8qtKThUY8SpfrLXu9H8pVkaC/IaMH4Lu7/BWsB5ONv/YGipQoUSJbNyVNvJdIdyhZUrlkZ
h3OyosnDWoq6TOOLq6urObrFhYwvAMDIUxRuVtLZbE7MoUEKiZBUM1HGpSitXO/C4AISxX2L1+Px
nFQ0TVm5jodTKEhI7FcEhVFrtfKoDWALbJ3reBKib52XdkuxLxBH0/DSahZQ1genRVHUbdV8L87W
iXBPgjMUSpmqON3FrOSshGDFRfJw3mtPPZeehRYNJ+BhZ9H045uGniNDpIHcZQCpiea+UOsWDRvy
zETsK5dCFpQ/pyrLsr08Skg998fG55WQCHMgacpqZUNySWs4aJF6dNyLozAMq8fOQht0JoR2CXbG
tKjiqHokSnCWkouZoccJHYXucg+nBuJvz+yC/nmKQYuKJkzvMIip9ZeVVa3/sfQ3RPw88BYqqtQW
Pfs8MFtUAh0o4JCY4Fq3pujuzJxTsLI5eXJtD37ybat6VTD9eS8J6OGlrxeFJsR9lB3bHDAWdY+b
yWTSJmybMw1tTuwdPJqdNgyTHLSau9wj/52/nK7gKKaW8cYhYinWc+ziTGlPOuNg4MbPYCtpFZsP
I+2EvZvzTHxjrYFs3LjQCA8TUVTiPGWvDd8bvlqmdNp75O/oxSHT8azjV2aKU4O323RAuUNNXYyZ
ppwl39hWmupaHdQK68RePo6XAS+nLskvX6wzMEzctT/i3v2/NTqfMUgPHL2aXZ1SQY9Pac1M4e20
NngNyfN16Fg8DptUXtQVF1iK04xxUIQNyMEKfeaEAz9qSwhnGzDmbzFMisBJcmH5cIcnMzCwG+o1
GXIFci+Lrg6+ZCWfnGkQkV+jT9mzGJxzJ35B04F4ql14lWI8Pch6ZH3tQLe1orvS9r+15S/YTovJ
XZdxglkE2fVDcoXXIjSRJrVUyOBKMCdxnuEHZB03Rfp8xENHm28YZgvay9qGQwguKtOSFXZoCNK6
mR7C4VTNvQ0zImEhY+WDv4q+O/kgwaM1Ap+Z8Qh8Gc0Kw6isLhNrGaiynfiXB9hlEs0qYu2iH+El
frSdxQwMZLq3hE6ZRVPwDwWR7zod6BzXvfQYGtvLhk7goLfiYH50bSeQNqttXe/E7mGDmTUt574w
0Jl/cbyCTEiws4NtznEfoU1A6pj0n2voNYUjBfaE8ZOG7+yGZzaZZd9vNsXZzdDWG3MMJ75Xve0a
je4E/oeuAkw3lf6AdVy7d7FhimkhFdFpXOo8SHLG09fjNwf1pD1N1UkC6rBbjK/HXfvKDgedppOP
u2YVJs5aRhmvJQyGIKU4Ohy3M9zsZaNJE9JiZKvXcjGyb5GFmenxbZCyDWHpTd+N1H18qUTLT8AR
ZnwxCKJzwAOk3r1CvQiVUd7TMoMoviS+Xv5x9+7j5VPvcL/hDIosXgUBwQ4kdUskEgRG8/b9uw93
7z4YZSMCZbon4Cw+G3SjIbpph8PlguIoDRm6r3UVj0ZbfFkN2+s8zOtRv3ls0SV5fWuo8zvTBFJm
9t+QHxJR7ebk10aB/ETetuwUco114gsCi8C5s5rYRhY5hMO+7/4Dqacp9vANAAA=
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
H4sIAAAAAAACA81YWW/jNhB+96+YqlhsEtiK7I1z2MUCxXaBLXo87IG+LLCgJMoiIpECSdlxi/z3
zpCSLTmJs00coA6SSCLn4BzffPLpCVS1hbWqNaiVBGPXhZAL+PD+43s4OR0MQs2XnBUQmkKk3MBb
MDyxQslQK8vo4hMthJbf2OGe3UxKVcuEl1xaJ7Fvc4JbbYr+fMfOslK/CFMVbP3o5kqLv/lCLPGA
7d60Lsv14J8BwOkJxCy5Xmi0nc7gxyzL5hSB28EgVul6CI3e0VLwVaW0baVSnrG6sJApaSFRhdIk
Bv6yUUS3tTZ0L5Xkc9L6oJ9QAamuWJqip6OCZ3YG06i6mXeearHIO48xaXyUc/9wPJm+ciZOTw75
+Tr44+ePv83A+Qtt+gdfD2qESs6KklsWF9zFoWR6IeQMIrjEwzb/6MxUciNWiAUuUpB8VLfCNh32
bvNeWGNlrSpnEL65mPLyjmzOWQpNhnM6Lz6B4DNuCOAUgvdLrOMAaBfXGIuVz3nqK7Gb5Y1Ouuh5
0KQwvGv+Gyf1dl3xb67AnRjV18hgBc8wAq82AbCaSZMpjUepq4rrhBlOi71ijljUKR60OealM7y9
cjJK43FGmqWiNlhH+xwzvBSS6We7xi4P7lqKWaGGeL5v0XN8w8pBA65wnG9AzhkIuK8dJlMISiak
Xw2G8Fed15AqbuRrCwsuuWaWAxvACUJDxdzdT6Zi8i2sBJZzX/McjIIVf605ZOyaQNzmwkBt6PLd
p0+kpjK8TtWIFw6HzRxWucBq91LMgrBDvIGESWAFqtN8lPKkYLjacdUEpMsqiHGrQlDX1gCe1CjM
RU7msCuvOfSbuZMgUuXuZrOYY4w4bLCUjJGGbmQaU6w1hm2n+U7DCUkZd0CLCSfVELzz22fBfAMj
m6Zruv559TG5TA5du4+FZScirkpE0pTBd8bFgdfLReUsSp7VNS8xszyM+kk7GB32M/jiWoxBJm54
Chh2hZTKdWjOdDqqlBE0KXEtVjeIADjiGSyFtjWO//HVJLoZR5cRmERzLsPBZ2rblSgKiDVn1yAy
4mcIAdZ1vMSxu+TNFKYUYY7dgoOPL79SbTC59o3IC8N/OPiBP/JSLbnHFywlgVXXcpfG2RUjVFKI
PlSlxiLYYSiciyPimBzStWSlSAY+XOEL0IjvJ40hHkKvIaQWIWjyU63N2wxYbFRRW1fqVlXIRRzn
csTMXWKPUgY6ChqIhbI2llrVZU9BVmNapaLRWTQp9KxtiFoQVBWq0SthPN/Q/HcXnaNjFJRNgA0+
bl3zKM/b3nZFh9XgIGDDBiNPmG6fFBJZl/F/j8dKpDYn0x47dl3pczcHPjugM55EzU4sNJ0VajUj
GpZyOe9Q62Y+O2UmZyntGp8jSXR/4gJRyamoWCIsgmEUTp8aBytsw0f3hGHjtA/FuL1twpGwIjka
X9FTGPnV4154zh4889OcZrXN1aPJe3P2//IaH1iaMY/5fXZ+v9/dYaQXMTsan18OI/wJL6bHnfJB
7uO1bSZVhBl0rxiTVlV/Rl1dXbXPbzYFd4YS9OtMRd4Q2bl9IgSVDjceOft0ujdn2/Zps+Sz6PoP
s+jEjw+ZNEdA/mRlh3SvGtPnvkvbpk3vado9MXwhQtD5LqClBYefQLtfONwbpgbwxh4qe5G7oFDd
NopwZNimmfusbbqB9862QnR3bl52G+7V4WYTImbR5uKOolDITEGIxM+9U9zJbqyK9E5679exxdCe
hunDEh7AenS4pbFBvIZgB92Rvj6kqVICX1ychv5LuifYwjSv/ThecUyXDF9fGpGlMILW2IK1o7WT
t4vpqx0nJs6HB13YHmZ7lKNgDntFWGZpCG8ljp3Ev0a0MIu+EwAA
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
