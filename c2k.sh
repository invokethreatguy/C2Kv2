#!/bin/bash
reset

# -------------------------------------------------------------------------------------
# -[Variables Section]-
BUILDDIR=$(pwd)
DOHOME="https://api.digitalocean.com/v2/droplets"
DOTOKEN="YOUR_API_KEY"
MALLEABLEDIR=$BUILDDIR/cobaltstrike/malleable_profiles
GHMALLEABLE="https://github.com/rsmudge/Malleable-C2-Profiles.git"
GHMODREWRITE="https://github.com/n0pe-sled/Apache2-Mod-Rewrite-Setup.git"
MODRWDIR=$BUILDDIR/mod_rewrite_setup
LWCONFIG=/usr/share/logwatch/default.conf/logwatch.conf
NEWUSER="YOUR_SSH_USERNAME"
# -------------------------------------------------------------------------------------
# -[Privilege Check Section]-
if [ $(id -u) -ne '0' ]; then
    echo
    echo ' [ERROR]: This Setup Script Requires root privileges!'
    echo '          Please run this setup script again with sudo or run as login as root.'
    echo
    exit 1
fi
# -------------------------------------------------------------------------------------
# -[Functions Section]-
func_getDependencies(){
  apt-get update
  apt-get install python python-pip git build-essential
}

func_createUser(){
  adduser $NEWUSER
  usermod -aG sudo $NEWUSER
}

func_setupSSH(){
  mkdir -p /home/$NEWUSER/.ssh
  cp sshd_config /etc/ssh/sshd_config
  cp /root/.ssh/authorized_keys /home/$NEWUSER/.ssh/authorized_keys
  chown -R $NEWUSER:$NEWUSER /home/$NEWUSER
  chmod 700 /home/$NEWUSER/.ssh
  chmod 644 /home/$NEWUSER/.ssh/authorized_keys
  service ssh restart
}

func_createDroplets(){
  # apt-get install snap
  # snap install doctl
  curl -X POST $DOHOME \
       -d'{"name":"dn-cs1","region":"tor1","size":"4gb","image":"ubuntu-16-04-x64","ssh_keys":["YOUR_SSH_FINGERPRINT"]}' \
       -H "Content-type: application/json" \
       -H "Authorization: Bearer $DOTOKEN" \
      | python -m json.tool
}

func_getCSDependencies(){
  apt-add-repository ppa:webupd8team/java
  apt-get update
  apt-get install oracle-java8-installer
  update-java-alternatives -s java-8-oracle
}

func_installCobaltStrike(){
  tar xvf cobaltstrike-trial.tgz
  cd cobaltstrike
  ./update
  cd $BUILDDIR
}

func_getMalleable(){
  git clone $GHMALLEABLE $MALLEABLEDIR
}

func_addHTTPSSupport(){
  chmod +x HTTPsC2DoneRight.sh
  ./HTTPsC2DoneRight.sh
}

func_createFirewall(){
  iptables -F
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -p tcp --dport 7654 -j ACCEPT
  iptables -A INPUT -p tcp --dport 50050 -j ACCEPT
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  iptables -I INPUT 1 -i lo -j ACCEPT
  iptables -P INPUT DROP
  iptables -P FORWARD DROP
}

func_createHTTPRedirector(){
  git clone $GHMODREWRITE $MODRWDIR
  git clone $GHMALLEABLE $BUILDDIR/malleable_profiles
  cd $MODRWDIR
  python apache_redirector_setup.py --ir --block_url="http://blockdomain.com" --block_mode="redirect" --allow_url="http://yourc2.com" --allow_mode="proxy"
}

func_installDefensiveTools(){
  apt-get update
  pip install lterm
  mkdir lterm_logs
  python /usr/local/bin/lterm.py -b -i -l $BUILDDIR/lterm_logs/
  apt-get install sendmail logwatch
  sed -i -e 's/MailTo = root/MailTo = your@email.com/' $LWCONFIG
  sed -i -e 's/Range = yesterday/Range = today/' $LWCONFIG
  sed -i -e 's/Detail = Low/Detail = Med/' $LWCONFIG
  (crontab -l 2>/dev/null; echo "0 * * * * /usr/sbin/logwatch --detail Med --mailto your@email.com --service all --range today") | crontab -
  apt-get install iptables-persistent
}

func_quitScript(){
  exit 0
}
# -------------------------------------------------------------------------------------
# -[ Banner Section]-
echo "                 -[C2K]-                "
echo "         Command and Control Kit v2.0   "
echo "                                        "
echo "[*] - Author: Lee Kagan      	      "
echo "[*] - Twitter: @InvokeThreatGuy         "
echo "[*] - Link: https://github.com/invokethreatguy/C2K"
echo "[*] - Blog: invokethreat.actor          "
echo "[*] - License: BSD 3-clause             "
echo ""
sleep 1
# -------------------------------------------------------------------------------------
# -[Main Menu Section]-
while true
do
  echo "- Main Menu -"
  echo "-------------"
  echo ""
  echo "======================================================================"
  echo "[*] REMEMBER TO EDIT SETTINGS FOR YOU REQUIREMENTS BEFORE RUNNING! [*]"
  echo "======================================================================"
  echo "Enter 1 to create new droplet(s)"
  echo "Enter 2 to build a Cobalt Strike team server on current system"
  echo "Enter 3 to add HTTPS support to team server on current system"
  echo "Enter 4 to build Apache redirector on current system"
  echo "Enter 5 to install logging and defensive tools"
  echo "Enter 99 to exit script"
  echo "Please enter your selection: "
  read answer
  case "$answer" in
# -------------------------------------------------------------------------------------
# -[User Selection Section]-
   1) clear
      echo "[*] - Creating droplet(s)..."
      func_createDroplets
      echo "[*] - COMPLETE!"
      ;;

   2) clear
      echo "[*] - Installing Cobalt Strike..."
      func_getDependencies
      func_createUser
      func_setupSSH
      func_getCSDependencies
      func_installCobaltStrike
      func_getMalleable
      func_createFirewall
      echo "[*] - COMPLETE!"
      ;;

   3) clear
      echo "[*] - Adding HTTPS support to Cobalt Strike Team Server..."
      func_addHTTPSSupport
      echo "[*] - COMPLETE!"
      ;;

   4) clear
      echo "[*] - Building Apache Mod_Rewrite redirector..."
      func_getDependencies
      func_createUser
      func_setupSSH
      func_createHTTPRedirector
      echo "[*] - COMPLETE!"
      ;;

   5) clear
      echo "[*] - Installing lterm and Logwatch"
      func_installDefensiveTools
      echo "[*] - COMPLETE!"
      ;;

   99) clear
      echo "[*] - Exiting script..."
      func_quitScript
      echo ""
      ;;
  esac
done
# -------------------------------------------------------------------------------------
