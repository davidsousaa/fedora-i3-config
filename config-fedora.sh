#! /usr/bin/env bash

#################
### VARIABLES ###
#################
RPMFUSIONCOMP="rpmfusion-free-appstream-data rpmfusion-nonfree-appstream-data rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted"
CODEC="gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugins-good-extras gstreamer1-plugins-bad-free-extras gstreamer1-plugins-ugly-free gstreamer1-plugin-libav gstreamer1-plugins-ugly libdvdcss gstreamer1-plugin-openh264"
LOGFILE="/tmp/config-fedora.log"
DNFVERSION="$(readlink $(which dnf))"
FC0=$(rpm -E %fedora)
FC1=$(($FC0 + 1))
#####################
### FIN VARIABLES ###
#####################


#################
### FONCTIONS ###
#################

check_cmd()
{
if [[ $? -eq 0 ]]
then
    	echo -e "\033[32mOK\033[0m"
else
    	echo -e "\033[31mERREUR\033[0m"
fi
}


check_repo_file()
{
	if [[ -e "/etc/yum.repos.d/$1" ]]
	then
		return 0
	else
		return 1
	fi
}

check_pkg()
{
	rpm -q "$1" > /dev/null
}
add_pkg()
{
	dnf install -y --nogpgcheck "$1" >> "$LOGFILE" 2>&1
}

del_pkg()
{
	if [[ "${DNFVERSION}" == "dnf-3" ]]
	then
		dnf autoremove -y "$1" >> "$LOGFILE" 2>&1
	fi
	if [[ "${DNFVERSION}" == "dnf5" ]]
	then
		dnf remove -y "$1" >> "$LOGFILE" 2>&1
	fi
}
swap_pkg()
{
	dnf swap -y "$1" "$2" --allowerasing > /dev/null 2>&1
}
check_flatpak()
{
	flatpak info "$1" > /dev/null 2>&1
}
add_flatpak()
{
	flatpak install flathub --noninteractive -y "$1" > /dev/null 2>&1
}
del_flatpak()
{
	flatpak uninstall --noninteractive -y "$1" > /dev/null && flatpak uninstall --unused  --noninteractive -y > /dev/null
}
check_copr()
{
	if [[ ${DNFVERSION} == "dnf-3" ]]
	then
		COPR_ENABLED=$(dnf copr list --enabled | grep -c "$1")
	fi
	if [[ ${DNFVERSION} == "dnf5" ]]
	then
		COPR_ENABLED=$(dnf copr list | grep -v '(disabled)' | grep -c "$1")
	fi
	return $COPR_ENABLED
}
add_copr()
{
	dnf copr enable -y "$1" > /dev/null 2>&1
}

refresh_cache()
{
	dnf check-update --refresh fedora-release > /dev/null 2>&1
}
refresh_cache_testing()
{
	dnf check-update --enablerepo=*updates-testing fedora-release > /dev/null 2>&1
}
check_updates_rpm()
{
	yes n | dnf upgrade
}
check_updates_testing_rpm()
{
	yes n | dnf upgrade --enablerepo=*updates-testing
}
check_updates_flatpak()
{
	yes n | flatpak update
}
need_reboot()
{
	if [[ ${DNFVERSION} == "dnf-3" ]]
	then
		needs-restarting -r >> "$LOGFILE" 2>&1
		NEEDRESTART="$?"
	fi
	if [[ ${DNFVERSION} == "dnf5" ]]
	then
		dnf needs-restarting -r >> "$LOGFILE" 2>&1
		NEEDRESTART="$?"
	fi
	return $NEEDRESTART
}
ask_reboot()
{
	echo -n -e "\033[5;33m/\ REDÉMARRAGE NÉCESSAIRE\033[0m\033[33m : Voulez-vous redémarrer le système maintenant ? [y/N] : \033[0m"
	read rebootuser
	rebootuser=${rebootuser:-n}
	if [[ ${rebootuser,,} == "y" ]]
	then
		echo -e "\n\033[0;35m Reboot via systemd ... \033[0m"
		sleep 2
		systemctl reboot
		exit
	fi
	if [[ ${rebootuser,,} == "k" ]]
	then
		kexec_reboot
	fi
}

kexec_reboot()
{
	echo -e "\n\033[1;4;31mEXPERIMENTAL :\033[0;35m Reboot via kexec ... \033[0m"	
	LASTKERNEL=$(rpm -q kernel --qf "%{INSTALLTIME} %{VERSION}-%{RELEASE}.%{ARCH}\n" | sort -nr | awk 'NR==1 {print $2}')
	kexec -l /boot/vmlinuz-$LASTKERNEL --initrd=/boot/initramfs-$LASTKERNEL.img --reuse-cmdline
	sleep 0.5
	# kexec -e
	systemctl kexec
	exit
}


ask_maj()
{
	echo -n -e "\n\033[36mVoulez-vous lancer les MàJ maintenant ? [y/N] : \033[0m"
	read startupdate
	startupdate=${startupdate:-n}
	echo ""
	if [[ ${startupdate,,} == "y" ]]
	then
		bash "$0"
	fi

}

upgrade_fc()
{
	if curl --fail -s --output /dev/null https://dl.fedoraproject.org/pub/fedora/linux/releases/$FC1
	then
		echo "Lancement de l'upgrade $FC0 -> $FC1"
		if dnf system-upgrade --releasever=$FC1 download
		then
			dnf system-upgrade reboot
		else
			echo -e "\033[31mERREUR lors de la phase préparatoire. Abandon! \033[0m"
			exit 3;
		fi
	else
		echo -e "\033[33mLa version $FC1 n'est pas notée stable. Abandon! \033[0m"
		exit 4;
	fi
}

#####################
### FIN FONCTIONS ###
#####################


####################
### DEBUT SCRIPT ###
####################

# Verif option
if [[ -z "$1" ]]
then
	echo "OK" > /dev/null
elif [[ "$1" == "coffee" ]] || [[ "$1" == "check" ]] || [[ "$1" == "testing" ]] || [[ "$1" == "upgrade" ]] || [[ "$1" == "scriptupdate" ]]
then
	echo "OK" > /dev/null
else
	echo "Incorrect use of script :"
	echo "- $(basename $0)              : Launches configuration and/or updates"
	echo "- $(basename $0) check        : Checks for available updates and suggests launching them"
	echo "- $(basename $0) testing      : Checks for available test updates"
	echo "- $(basename $0) upgrade      : Starts Fedora upgrade to the next version"
	echo "- $(basename $0) scriptupdate : Update script from Github"
	exit 1;
fi

# Easter Egg
if [[ "$1" = "coffee" ]]
then
	echo "Yes, the script makes coffee !"
	echo ""
	echo '    (  )   (   )  )'
	echo '     ) (   )  (  ('
	echo '     ( )  (    ) )'
	echo '     _____________'
	echo '    <_____________> ___'
	echo '    |             |/ _ \'
	echo '    |               | | |'
	echo '    |               |_| |'
	echo ' ___|             |\___/'
	echo '/    \___________/    \'
	echo '\_____________________/'
	echo ""
	echo "Impressive!?"

	exit 0;
fi

# Upgrade Fedora
if [[ "$1" = "upgrade" ]]
then
	upgrade_fc
fi

# Script Update
if [[ "$1" = "scriptupdate" ]]
then
	echo $0
	wget -O- https://raw.githubusercontent.com/davidsousaa/fedora-i3-config/refs/heads/main/config-fedora.sh > "$0"
	chmod +x "$0"

	wget -O- -q https://raw.githubusercontent.com/davidsousaa/fedora-i3-config/refs/heads/main/CHANGELOG.txt | head

	exit 0;
fi

# Test if root
if [[ $(id -u) -ne "0" ]]
then
	echo -e "\033[31mERREUR\033[0m Run the script as root (su - root or sudo)"
	exit 1;
fi

# Test if Fedora i3 Spin is installed
if ! check_pkg fedora-release-i3
then
    echo -e "\033[31mERROR\033[0m Only Fedora i3 Spin is supported!"
    exit 2;
fi


# Log file info
echo -e "\033[36m"
echo "To track the progress of updates : tail -f $LOGFILE"
echo -e "\033[0m"

# Date dans le log
echo '-------------------' >> "$LOGFILE"
date >> "$LOGFILE"


#################
### PROGRAMME ###
#################
ICI=$(dirname "$0")


## CAS CHECK-UPDATES
if [[ "$1" = "check" ]]
then
	echo -n "01- - Refresh du cache : "
	refresh_cache
	check_cmd

	echo "02- - Mises à jour disponibles RPM : "
	check_updates_rpm

	echo "03- - Mises à jour disponibles FLATPAK : "
	check_updates_flatpak

	ask_maj

	exit;
fi

## CAS CHECK-UPDATES-TESTING
if [[ "$1" = "testing" ]]
then
	echo -n "01- - Refresh du cache : "
	refresh_cache_testing
	check_cmd
	
	echo "02- - Mises à jour disponibles RPM TESTING : "
	check_updates_testing_rpm

	echo -e "\n \033[36mRAPPEL : Pas de MàJ testing gérée par le script ! Pour upgrader un paquet en testing : " 
	echo -e "         dnf upgrade --enablerepo=*updates-testing paquet1 paquet2 \033[0m \n"

	exit;
fi


### CONF DNF
echo "01- Vérification configuration DNF"
# plus necessaire avec dnf5, option non prise en compte
#if [[ $(grep -c 'fastestmirror=' /etc/dnf/dnf.conf) -lt 1 ]]
#then
#	echo -n "- - - Correction miroirs rapides : "
#	echo "fastestmirror=true" >> /etc/dnf/dnf.conf
#	check_cmd
#fi
if [[ $(grep -c 'max_parallel_downloads=' /etc/dnf/dnf.conf) -lt 1 ]]
then
	echo -n "- - - Correction téléchargements parallèles : "
	echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
	check_cmd
fi
if [[ $(grep -c 'countme=' /etc/dnf/dnf.conf) -lt 1 ]]
then
	echo -n "- - - Correction statistiques : "
	echo "countme=false" >> /etc/dnf/dnf.conf
	check_cmd
fi
if [[ $(grep -c 'deltarpm=' /etc/dnf/dnf.conf) -lt 1 ]]
then
        echo -n "- - - Correction deltarpm désactivés : "
        echo "deltarpm=false" >> /etc/dnf/dnf.conf
        check_cmd
fi

echo -n "- - - Refresh du cache : "
refresh_cache
check_cmd

if ! check_pkg "dnf-utils"
then
	echo -n "- - - Installation dnf-utils : "
	add_pkg "dnf-utils"
	check_cmd
fi


### MAJ RPM
echo -n "02- Mise à jour du système DNF : "
dnf update -y >> "$LOGFILE" 2>&1
check_cmd


### MAJ FP
echo -n "03- Mise à jour du système FLATPAK : "
flatpak update --noninteractive >> "$LOGFILE"  2>&1
check_cmd

# Verif si reboot nécessaire
if ! need_reboot
then
	ask_reboot
fi


### CONFIG DEPOTS
echo "04- Vérification configuration des dépôts"
## COPR PERSO
if check_copr 'adriend/fedora-apps'
then
	echo -n "- - - Activation COPR adriend/fedora-apps : "
	add_copr "adriend/fedora-apps"
	check_cmd
fi


## RPMFUSION
if ! check_pkg rpmfusion-free-release
then
	echo -n "- - - Installation RPM Fusion Free : "
	add_pkg "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
	check_cmd
fi
if ! check_pkg rpmfusion-nonfree-release
then
	echo -n "- - - Installation RPM Fusion Nonfree : "
	add_pkg "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
	check_cmd
fi

## VIVALDI
if ! check_repo_file vivaldi.repo
then
	echo -n "- - - Installation Vivaldi Repo : "
	echo "[vivaldi]
	name=vivaldi
	baseurl=https://repo.vivaldi.com/archive/rpm/x86_64
	enabled=1
	gpgcheck=1
	gpgkey=http://repo.vivaldi.com/archive/linux_signing_key.pub" 2>/dev/null > /etc/yum.repos.d/vivaldi.repo
	check_cmd
	sed -e 's/\t//g' -i /etc/yum.repos.d/vivaldi.repo
fi

## FLATHUB
if [[ $(flatpak remotes | grep -c flathub) -ne 1 ]]
then
	echo -n "- - - Installation Flathub : "
	flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null
	check_cmd
fi

## COMPOSANTS RPM FUSION
echo "05- Vérification composants RPM Fusion"
for p in $RPMFUSIONCOMP
do
	if ! check_pkg "$p"
	then
		echo -n "- - - Installation composant RPM Fusion $p : "
		add_pkg "$p"
		check_cmd
	fi
done

### SWAPPING DES SOFT 
echo "06- Vérification swapping des composants"

## FFMPEG
if check_pkg "ffmpeg-free"
then
	echo -n "- - - Swapping ffmpeg : "
	swap_pkg "ffmpeg-free" "ffmpeg" 
	check_cmd
fi

## MESA-VA
#if check_pkg "mesa-va-drivers"
#then
#	echo -n "- - - Swapping MESA VAAPI : "
#	swap_pkg "mesa-va-drivers" "mesa-va-drivers-freeworld"
#	check_cmd
#fi

## MESA-VDPAU
#if check_pkg "mesa-vdpau-drivers"
#then
#	echo -n "- - - Swapping MESA VDPAU : "
#	swap_pkg "mesa-vdpau-drivers" "mesa-vdpau-drivers-freeworld"
#	check_cmd
#fi

## INSTALL CODECS
echo "07- Vérification CoDec"
for p in $CODEC
do
	if ! check_pkg "$p"
	then
		echo -n "- - - Installation CoDec $p : "
		add_pkg "$p"
		check_cmd
	fi
done


### INSTALL/SUPPRESSION RPMS SELON LISTE
echo "09- Gestion des paquets RPM"
while read -r line
do
	if [[ "$line" == add:* ]]
	then
		p=${line#add:}
		if ! check_pkg "$p"
		then
			echo -n "- - - Installation paquet $p : "
			add_pkg "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]
	then
		p=${line#del:}
		if check_pkg "$p"
		then
			echo -n "- - - Suppression paquet $p : "
			del_pkg "$p"
			check_cmd
		fi
	fi
done < "$ICI/packages.list"

### INSTALL/SUPPRESSION FLATPAK SELON LISTE
echo "10- Gestion des paquets FLATPAK"
while read -r line
do
	if [[ "$line" == add:* ]]
	then
		p=${line#add:}
		if ! check_flatpak "$p"
		then
			echo -n "- - - Installation flatpak $p : "
			add_flatpak "$p"
			check_cmd
		fi
	fi
	
	if [[ "$line" == del:* ]]
	then
		p=${line#del:}
		if check_flatpak "$p"
		then
			echo -n "- - - Suppression flatpak $p : "
			del_flatpak "$p"
			check_cmd
		fi
	fi
done < "$ICI/flatpak.list"

### Verify system configuration
echo "11- Configuration personnalisée du système"
SYSCTLFIC="/etc/sysctl.d/adrien.conf"
if [[ ! -e "$SYSCTLFIC" ]]
then
	echo -n "- - - Création du fichier $SYSCTLFIC : "
	touch "$SYSCTLFIC"
	check_cmd
fi
if [[ $(grep -c 'vm.swappiness' "$SYSCTLFIC") -lt 1 ]]
then
	echo -n "- - - Définition du swapiness à 10 : "
	echo "vm.swappiness = 10" >> "$SYSCTLFIC"
	check_cmd
fi
if [[ $(grep -c 'kernel.sysrq' "$SYSCTLFIC") -lt 1 ]]
then
	echo -n "- - - Définition des sysrq à 1 : "
	echo "kernel.sysrq = 1" >> "$SYSCTLFIC"
	check_cmd
fi

if ! check_pkg "pigz"
then
	echo -n "- - - Installation pigz : "
	add_pkg "pigz"
	check_cmd
fi
if [[ ! -e /usr/local/bin/gzip ]]
then
	echo -n "- - - Configuration gzip multithread : "
	ln -s /usr/bin/pigz /usr/local/bin/gzip
	check_cmd
fi
if [[ ! -e /usr/local/bin/gunzip ]]
then
	echo -n "- - - Configuration gunzip multithread : "
	ln -s /usr/local/bin/gzip /usr/local/bin/gunzip
	check_cmd
fi
if [[ ! -e /usr/local/bin/zcat ]]
then
	echo -n "- - - Configuration zcat multithread : "
	ln -s /usr/local/bin/gzip /usr/local/bin/zcat
	check_cmd
fi


if ! check_pkg "lbzip2"
then
	echo -n "- - - Installation lbzip2 : "
	add_pkg "lbzip2"
	check_cmd
fi
if [[ ! -e /usr/local/bin/bzip2 ]]
then
	echo -n "- - - Configuration bzip2 multithread : "
	ln -s /usr/bin/lbzip2 /usr/local/bin/bzip2
	check_cmd
fi
if [[ ! -e /usr/local/bin/bunzip2 ]]
then
	echo -n "- - - Configuration bunzip2 multithread : "
	ln -s /usr/local/bin/bzip2 /usr/local/bin/bunzip2
	check_cmd
fi
if [[ ! -e /usr/local/bin/bzcat ]]
then
	echo -n "- - - Configuration bzcat multithread : "
	ln -s /usr/local/bin/bzip2 /usr/local/bin/bzcat
	check_cmd
fi

# Check if Zsh is installed
if ! check_pkg "zsh"; then
    echo -n "- - - Installing Zsh: "
    add_pkg "zsh"
    check_cmd
fi

# Check if Oh-My-Zsh is already installed
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo -n "- - - Installing Oh-My-Zsh: "
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash >/dev/null 2>&1
    check_cmd
fi

# Restore previous configuration if available
if [[ -f "$HOME/.zshrc" ]]; then
    echo -n "- - - Backing up existing .zshrc: "
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
    check_cmd
fi

# Symlink or copy your preconfigured .zshrc
if [[ -f "$ICI/configs/zsh/.zshrc" ]]; then
    echo -n "- - - Restoring preconfigured .zshrc: "
    cp "$ICI/configs/zsh/.zshrc" "$HOME/.zshrc"
    check_cmd
fi

# Set Zsh as the default shell
echo -n "- - - Setting Zsh as the default shell: "
chsh -s "$(which zsh)" "$USER"
check_cmd


# Verify if reboot is needed
if ! need_reboot
then
	ask_reboot
fi
