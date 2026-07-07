#!/bin/bash

# ======================================================
# Kali Cleaner v2.0
# Safe Interactive Disk Cleanup Tool
# ======================================================

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"


pause(){
    read -p "Press Enter to continue..."
}


confirm(){
    read -p "Confirm? (y/N): " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]]
}


banner(){

clear

echo -e "${CYAN}"

cat << "EOF"

 ██╗  ██╗ █████╗ ██╗     ██╗
 ██║ ██╔╝██╔══██╗██║     ██║
 █████╔╝ ███████║██║     ██║
 ██╔═██╗ ██╔══██║██║     ██║
 ██║  ██╗██║  ██║███████╗██║
 ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝

        KALI CLEANER v2.0
     Safe Disk Maintenance Tool

EOF

echo -e "${RESET}"

}


disk(){

echo -e "${GREEN}Disk usage:${RESET}"

df -h /

pause
}



root_scan(){

echo "Largest root folders"

sudo du -xh / --max-depth=1 2>/dev/null | sort -h

pause

}


home_scan(){

echo "Largest home folders"

du -xh ~ --max-depth=1 2>/dev/null | sort -h

pause

}



var_scan(){

echo "VAR usage"

sudo du -xh /var --max-depth=1 2>/dev/null | sort -h

pause

}



opt_scan(){

echo "OPT usage"

sudo du -xh /opt --max-depth=1 2>/dev/null | sort -h

pause

}



large_files(){

echo "Searching files bigger than 1GB"

sudo find / -type f -size +1G 2>/dev/null | less

}



large_dirs(){

sudo du -xh / --max-depth=2 2>/dev/null |
sort -h |
tail -50 |
less

}



apt_clean(){

echo "APT cache:"

sudo du -sh /var/cache/apt 2>/dev/null


if confirm
then

sudo apt clean
sudo apt autoclean
sudo apt autoremove --purge

fi


pause

}



journal_clean(){

journalctl --disk-usage

echo

echo "Reduce journal logs to 200MB?"

if confirm
then

sudo journalctl --vacuum-size=200M

fi

pause

}



cache_clean(){

echo "Cache sizes"

du -sh ~/.cache ~/.npm ~/.cache/pip 2>/dev/null


if confirm
then

rm -rf ~/.cache/*
npm cache clean --force 2>/dev/null
rm -rf ~/.cache/pip

fi


pause

}



developer_clean(){

echo

echo "Developer caches:"

du -sh \
~/.npm \
~/.gradle \
~/.cargo \
~/.rustup \
~/go/pkg/mod \
~/.m2 \
~/.pub-cache \
2>/dev/null


echo

if confirm
then

rm -rf ~/.gradle/caches
rm -rf ~/.cargo/registry
rm -rf ~/.cargo/git
rm -rf ~/.m2/repository
rm -rf ~/go/pkg/mod
rm -rf ~/.pub-cache

fi


pause

}



trash_clean(){

du -sh ~/.local/share/Trash 2>/dev/null


if confirm
then

rm -rf ~/.local/share/Trash/*

fi


pause

}



docker_menu(){

if ! command -v docker >/dev/null
then

echo "Docker not installed"
pause
return

fi


docker system df

echo

echo "Prune unused docker data?"

if confirm
then

docker system prune -a
docker volume prune

fi


pause

}



steam_menu(){

if ! command -v dpkg >/dev/null
then
return
fi


echo "Steam status"

dpkg -l | grep steam

du -sh ~/.local/share/Steam 2>/dev/null


echo

echo "Remove Steam completely?"

if confirm
then

sudo apt purge steam-launcher steam-libs-amd64 steam-libs-i386

sudo apt autoremove --purge

rm -rf ~/.local/share/Steam
rm -rf ~/.steam


fi


pause

}



minecraft_menu(){

echo "Minecraft size"

du -sh ~/.minecraft 2>/dev/null


echo

echo "Largest Minecraft folders"

du -xh ~/.minecraft --max-depth=2 2>/dev/null |
sort -h |
tail -20


echo

echo "Remove spark profiler data?"

if confirm
then

rm -rf ~/.minecraft/config/spark

fi


pause

}



browser_clean(){

echo "Browser caches"

du -sh \
~/.cache/google-chrome \
~/.cache/chromium \
~/.cache/mozilla \
2>/dev/null


if confirm
then

rm -rf ~/.cache/google-chrome
rm -rf ~/.cache/chromium
rm -rf ~/.cache/mozilla

fi


pause

}



package_report(){

echo "Largest installed packages"

dpkg-query -Wf '${Installed-Size}\t${Package}\n' |
sort -n |
tail -40 |
awk '{printf "%.2f MB\t%s\n",$1/1024,$2}' |
less

}



security_report(){

echo "Security tools"

for x in burpsuite zaproxy metasploit-framework ghidra seclists exploitdb maltego
do

dpkg -s $x 2>/dev/null |
grep -E "Package|Installed-Size"

done


pause

}



full_scan(){

disk
root_scan
home_scan
var_scan
opt_scan

}



while true
do

banner

echo "
1  Disk usage
2  Root scan
3  Home scan
4  Var scan
5  Opt scan
6  Find huge files
7  Find huge folders

8  APT cleanup
9  Journal cleanup
10 Cache cleanup
11 Developer cache cleanup
12 Empty trash

13 Docker cleanup
14 Steam removal
15 Minecraft cleanup
16 Browser cleanup

17 Installed package report
18 Security tools report

19 Full scan

0 Exit
"

read -p "Select: " choice


case $choice in

1) disk ;;
2) root_scan ;;
3) home_scan ;;
4) var_scan ;;
5) opt_scan ;;
6) large_files ;;
7) large_dirs ;;

8) apt_clean ;;
9) journal_clean ;;
10) cache_clean ;;
11) developer_clean ;;
12) trash_clean ;;

13) docker_menu ;;
14) steam_menu ;;
15) minecraft_menu ;;
16) browser_clean ;;

17) package_report ;;
18) security_report ;;

19) full_scan ;;

0)
exit
;;

*)
echo "Invalid option"
sleep 1
;;

esac

done
