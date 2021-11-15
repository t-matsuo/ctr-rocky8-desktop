#!/bin/bash

if [ ! -d /var/run/nafder ]; then
    mkdir -p /var/run/nafder
fi
rm -rf /var/run/nafder/*
mkfifo /var/run/nafder/entrypoint
nafder -t /var/run/nafder > /dev/console &
NAFDER_PID=$!

exec 1>>/var/run/nafder/entrypoint
exec 2>>/var/run/nafder/entrypoint

# copy or update mode
if [ "$1" = "--copy" ] || [ "$1" = "--update" ]; then
    MODE=$1
    echo "run $MODE mode"
    if [ "$2" = "" ]; then
        echo "$MODE options needs directory path"
        echo "(ex) $MODE /my-volume"
        exit 1
    fi
    if [ ! -d "$2" ]; then
        echo "$2 directory not found"
        exit 1
    fi
    VOL=$2

    if [ "$MODE" = "--update" ]; then
        echo "back up files to $VOL/.ctr-desktop-backup"
        mkdir $VOL/.ctr-desktop-backup
        if [ -f "$VOL/etc/machine-id" ]; then
            echo "backing up /etc/machine-id ...."
            cp -a $VOL/etc/machine-id $VOL/.ctr-desktop-backup/
        fi
        ls $VOL/etc/ssh/*key > /dev/null 2>&1
        if [ $? = 0 ]; then
            echo "backing up /etc/ssh/ keys ...."
            mkdir $VOL/.ctr-desktop-backup/ssh
            cp -a $VOL/etc/ssh/*.key $VOL/.ctr-desktop-backup/ssh/
            cp -a $VOL/etc/ssh/*.pub $VOL/.ctr-desktop-backup/ssh/
        fi
    fi
    for i in container etc home opt root run srv tmp usr var; do
        if [ "$MODE" = "--update" ]; then
            if [ "$i" = "root" ] || [ "$i" = "home" ]; then
                continue
            fi
            echo "deleting $VOL/$i ..."
            rm -rf $VOL/$i
        fi
        if [ -d "$VOL/$i" ]; then
            echo "$VOL/$i dir exists. skip copy"
            continue
        fi
        echo "copying /$i dir into $VOL ..."
        cp -a /$i $2/
    done
    if [ "$MODE" = "--update" ]; then
        echo "restore files from $VOL/.ctr-desktop-backup"
        if [ -f "$VOL/.ctr-desktop-backup/machine-id" ]; then
            echo "restoring /etc/machine-id ...."
            cp -a $VOL/.ctr-desktop-backup/machine-id $VOL/etc/machine-id
        fi
        if [ -d "$VOL/.ctr-desktop-backup/ssh" ]; then
            echo "restoring /etc/ssh/ keys ...."
            cp -a $VOL/.ctr-desktop-backup/ssh/*.key $VOL/etc/ssh/
            cp -a $VOL/.ctr-desktop-backup/ssh/*.pub $VOL/etc/ssh/
        fi
        touch $VOL/etc/update-done
    fi

    echo "done"
    exit 0
fi
# end of copy or update mode

if [ "$1" != "" ]; then
    exec $@
fi

function disable_service {
    if [ -f "$1" ]; then
        sed -i 's/autostart=true/autostart=false/g' $1
        sed -i 's/autorestart=true/autorestart=false/g' $1
    fi
}

if [ -f /etc/supervisord.d/nginx.ini ]; then
    if [ "$PORT" = "" ]; then
        PORT=8080
    fi
    export PORT
fi

if [ "$USER" = "" ]; then
    USER="root"
fi

# pre hook
if [ "$PRE_HOOK" != "" ]; then
    echo "---- pre hook : $PRE_HOOK --------------"
    source $PRE_HOOK || exit 1
    echo "----------------------------------------"
fi

if [ ! -f /etc/init-done ]; then
    # pre hook (once)
    if [ "$PRE_HOOK_ONCE" != "" ]; then
        echo "---- pre hook once : $PRE_HOOK_ONCE ----"
        source $PRE_HOOK_ONCE || exit 1
        echo "----------------------------------------"
    fi

    if [ ! -f /etc/update-done ]; then
        /bin/dbus-uuidgen > /etc/machine-id
    fi

    if [ "$DISABLE_DESKTOP" = "true" ]; then
        disable_service /etc/supervisord.d/vnc.ini
        disable_service /etc/supervisord.d/xrdp.ini
        disable_service /etc/supervisord.d/xrdp-sesman.ini
    fi
    if [ "$DISABLE_TERMINAL" = "true" ]; then
        disable_service /etc/supervisord.d/ttyd.ini
    fi
    if [ "$DISABLE_FILER" = "true" ]; then
        disable_service /etc/supervisord.d/filebrowser.ini
    fi
    if [ "$DISABLE_SSH" = "true" ]; then
        disable_service /etc/supervisord.d/sshd.ini
    fi
    if [ "$DISABLE_RDP" = "true" ]; then
        disable_service /etc/supervisord.d/xrdp.ini
        disable_service /etc/supervisord.d/xrdp-sesman.ini
    fi
    if [ "$DISABLE_CODE" = "true" ]; then
        disable_service /etc/supervisord.d/code.ini
    fi

    if [ "$DELETE_DESKTOP" = "true" ]; then
        rm -f /etc/supervisord.d/vnc.ini
        rm -f /etc/supervisord.d/xrdp.ini
        rm -f disable_service /etc/supervisord.d/xrdp-sesman.ini
        rm -f /etc/nginx/default.d/desktop.conf
    fi
    if [ "$DELETE_TERMINAL" = "true" ]; then
        rm -f /etc/supervisord.d/ttyd.ini
        rm -f /etc/nginx/default.d/term.conf
    fi
    if [ "$DELETE_FILER" = "true" ]; then
        rm -f disable_service /etc/supervisord.d/filebrowser.ini
        rm -f /etc/nginx/default.d/file.conf
    fi
    if [ "$DELETE_SSH" = "true" ]; then
        rm -f disable_service /etc/supervisord.d/sshd.ini
    fi
    if [ "$DELETE_RDP" = "true" ]; then
        rm -f /etc/supervisord.d/xrdp.ini
        rm -f /etc/supervisord.d/xrdp-sesman.ini
    fi
    if [ "$DELETE_CODE" = "true" ]; then
        rm -f /etc/supervisord.d/code.ini
    fi

    if [ -f /etc/ssh/sshd_config ]; then
        # change sshd port
        if [ "$SSH_PORT" != "" ]; then
            sed -i "s/^#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config
        fi

        # disable ssh password login
        if [ "$DISABLE_SSH_PASSWORD_LOGIN" = "true" ]; then
            sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
        fi
 
        # insert ssh public key
        if [ "$SSH_KEY" != "" ] && [ ! -f /etc/update-done ]; then
            mkdir $HOME/.ssh
            chmod 700 $HOME/.ssh
            echo $SSH_KEY >> $HOME/.ssh/authorized_keys
            chmod 600 $HOME/.ssh/authorized_keys
        fi
    fi

    if [ -f /etc/xrdp/xrdp.ini ]; then
        # change rdp port
        if [ "$RDP_PORT" != "" ]; then
            sed -i "s/^port=3389/port=$RDP_PORT/g" /etc/xrdp/xrdp.ini
        fi
    fi

    if [ -f /etc/supervisord.d/vnc.ini ] && [ ! -f /etc/update-done ]; then
        mkdir $HOME/.vnc
        echo "$VNC_RESOLUTION" | grep -q "^[0-9]*x[0-9]*$"
        if [ $? -ne 0 ]; then
            echo "invalid resolution $VNC_RESOLUTION"
            echo "set vnc resolution 1800x850"
            echo "geometry=1800x850" >> $HOME/.vnc/config
        else
            echo "set vnc resolution $VNC_RESOLUTION"
            echo "geometry=$VNC_RESOLUTION" >> $HOME/.vnc/config
        fi
        echo "$VNC_COL_DEPTH" | grep -q -e "^16$" -e "^24$" -e "^32$"
        if [ $? -ne 0 ]; then
            echo "invalid color depth $VNC_COL_DEPTH"
            echo "set vnc color depth 16"
            echo "depth=16" >> $HOME/.vnc/config
        else
            echo "set vnc color depth $VNC_COL_DEPTH"
            echo "depth=$VNC_COL_DEPTH" >> $HOME/.vnc/config
        fi
    fi

    if [ -f /etc/supervisord.d/nginx.ini ]; then
        # initializing nginx
        mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.org
        if [ "$NOSSL" = "true" ]; then
            sed "s/^#http/     /g" /etc/nginx/nginx.conf.tmpl > /etc/nginx/nginx.conf
        else
            sed "s/^#ssl/     /g" /etc/nginx/nginx.conf.tmpl > /etc/nginx/nginx.conf
            if [ ! -f /etc/pki/nginx/server.key ]; then
                openssl genrsa 2048 > /etc/pki/nginx/server.key
                openssl req -new -key /etc/pki/nginx/server.key <<EOF > /etc/pki/nginx/server.csr
JP
Default Prefecture
Default City
Default Company
Default Section
localhost



EOF
                openssl x509 -days 3650 -req -signkey /etc/pki/nginx/server.key < /etc/pki/nginx/server.csr > /etc/pki/nginx/server.crt
            fi
        fi
        sed -i "s/8080/$PORT/g" /etc/nginx/nginx.conf
        # initializing nginx done
    fi

    if [ "$DOCKER_HOST" != "" ] && [ ! -f /etc/update-done ]; then
        echo "export DOCKER_HOST=$DOCKER_HOST" >> $HOME/.bashrc
    fi

    if [ "$PASSWORD" = "" ]; then
        PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
        if [ "$HIDE_PASSWORD" != "true" ]; then
            echo
            echo "*******************************************"
            echo "***** $USER password is \"$PASSWORD\" *********"
            echo "*******************************************"
            echo
        fi
    fi

    if [ -f /etc/supervisord.d/xrdp.ini ]; then
        echo "Generating xrdp new rsa key"
        openssl req -x509 -newkey rsa:4096 -keyout /etc/xrdp/key.pem -sha256 -nodes -out /etc/xrdp/cert.pem -days 365 -subj "/CN=$(hostname)"
    fi

    if [ "$USER" != "root" ]; then
        echo "Setting up $USER user"
        if [ "$ROOT_PASSWORD" = "" ]; then
            ROOT_PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
            if [ "$HIDE_ROOT_PASSWORD" != "true" ]; then
                echo
                echo "*******************************************"
                echo "***** root password is \"$ROOT_PASSWORD\" *********"
                echo "*******************************************"
                echo
            fi
        fi
        echo "root:${ROOT_PASSWORD}" | chpasswd

        echo $USER | grep -q -w -e bin -e daemon -e adm -e lp -e sync -e shutdown \
                                -e halt -e mail -e operator -e games -e ftp -e nobody \
                                -e systemd-network -e dbus -e tcpdump -e nginx \
                                -e avahi -e tss -e sshd -e polkitd -e rtkit -e pulse \
                                -e geoclue
        if [ $? -eq 0 ]; then
            echo "invalid user name: $USER"
            exit 1
        fi

        if [ "$USER_ID" != "" ]; then
            if [ $USER_ID -lt 1000 ]; then
                echo "invalid uid: $USER_ID"
                exit 1
            fi
        else
            USER_ID=1000
        fi

        if [ ! -f /etc/update-done ]; then
            if [ -d /home/$USER ]; then
                echo "/home/$USER dir exists. copy /root into /home/$USER/root"
                echo '$ ls -l /home'
                ls -l /home
                echo "-------------"
                cp -a /root/ /home/$USER
                if [ ! -d /home/$USER/.local/share/code-server ]; then
                     mkdir -p /home/$USER/.local/share
                     cp -a /home/$USER/root/.local/share/code-server /home/$USER/.local/share/
                fi
            else
                echo "copying /root to /home/$USER ..."
                cp -a /root/ /home/$USER
            fi
        fi

        useradd $USER -u $USER_ID -G tty -d /home/$USER
        if [ ! -f /etc/update-done ]; then
            chown -R $USER:root /home/$USER
        fi
        echo "${USER}:${PASSWORD}" | chpasswd

        if [ -f /etc/supervisord.d/sshd.ini ]; then
            chown $USER:root /etc/ssh/sshd_config
            chown -R $USER:root /etc/sysconfig
            chown -R $USER:root /etc/ssh/
            chown root:root /etc/ssh/ssh_config.d/05-redhat.conf
        fi

        chown -R $USER:root /var/run/

        if [ -f /etc/supervisord.d/nginx.ini ]; then
            chown $USER:root /var/lib/nginx/
            chown -R $USER:root /var/lib/nginx/
        fi

        chown -R $USER:root $CTR_LOG
        chown -R $USER:root /var/log

        rm -rf /root/.ssh

        if [ -f /etc/supervisord.d/filebrowser.ini ]; then
            chown -R $USER:root /var/lib/filebrowser
            sed -i "s#-r /root#-r /home/$USER#g" /etc/supervisord.d/filebrowser.ini
        fi

        if [ -f /etc/supervisord.d/xrdp.ini ]; then
            chmod o+r /etc/xrdp/*.pem
            chmod o+r /etc/xrdp/rsakeys.ini
            sed -i "s/^username=ask$/username=$USER/g" /etc/xrdp/xrdp.ini
        fi

        if [ -f /etc/supervisord.d/vnc.ini ] && [ ! -f /etc/update-done ]; then
            sed -i "s#sql:/root#sql:/home/$USER#g" /home/$USER/.mozilla/firefox/mamdd1gq.default-release/pkcs11.txt
            sed -i "s#file:///root#file:///home/$USER#g" /home/$USER/.mozilla/firefox/mamdd1gq.default-release/extensions.json
        fi

        for i in ttyd.ini filebrowser.ini vnc.ini; do
            if [ -f /etc/supervisord.d/$i ]; then
                echo "directory=/home/$USER" >> /etc/supervisord.d/$i
                echo "environment=HOME=\"/home/$USER\",LANG='ja_JP.utf8'",LANGUAGE='ja_JP:ja',LC_ALL='ja_JP.UTF-8' >> /etc/supervisord.d/$i
            fi
        done

        if [ -f /etc/supervisord.d/code.ini ]; then
            echo "directory=/home/$USER" >> /etc/supervisord.d/code.ini
            echo "environment=HOME=\"/home/$USER\"" >> /etc/supervisord.d/code.ini
            if [ ! -f /etc/update-done ]; then
                sed -i "s#/root/#/home/$USER/#g" /home/$USER/.local/share/code-server/languagepacks.json
            fi
        fi

        if [ "$ENABLE_SUDO" = "true" ]; then
            echo "$USER	ALL=(ALL)	NOPASSWD: ALL" >> /etc/sudoers
        fi
    else
        echo "root:${PASSWORD}" | chpasswd
        if [ -f /etc/supervisord.d/xrdp.ini ]; then
            sed -i "s/^username=ask$/username=root/g" /etc/xrdp/xrdp.ini
        fi
    fi

    # post hook (once)
    if [ "$POST_HOOK_ONCE" != "" ]; then
        echo "---- post hook once : $POST_HOOK_ONCE ----"
        source $POST_HOOK_ONCE || exit 1
        echo "----------------------------------------"
    fi
    touch /etc/init-done
else
    echo "skip initializing"
fi

if [ -f /etc/supervisord.d/ttyd.ini ]; then
    if [ "$TTYD_OPTS" = "" ]; then
        TTYD_OPTS='-P 30'
    fi
    export TTYD_OPTS
fi

# post hook
if [ "$POST_HOOK" != "" ]; then
    echo "---- post hook : $POST_HOOK ------------"
    source $POST_HOOK || exit 1
    echo "----------------------------------------"
fi

unset PASSWORD
unset ROOT_PASSWORD
unset VNC_RESOLUTION
unset VNC_COL_DEPTH

exec 1>/dev/tty
exec 2>/dev/tty
kill $NAFDER_PID
if [ "$USER" != "root" ]; then
   exec gosu $USER /container/scripts/supervisord_startup.sh
fi
exec /container/scripts/supervisord_startup.sh
