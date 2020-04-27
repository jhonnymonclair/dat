#!/bin/bash
###################################################
##
## Dat.sh
## Dump-And-Tar for .RRD files
##
###################################################                                                                  #
#
#
# VARIABLES
#
TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
WORKDIR="/home/pi"
TARGETDIR="/var/lib/collectd/rrd"
PREFIX="adsb-data_"
SCPMACHINE="192.168.2.50"

function backup {

FILELIST=`find ${TARGETDIR} -name '*.rrd'`
if [[ -z "${FILELIST}" ]]; then
    echo -e "\e[91m  No available files to backup!\e[97m"
    return 1
fi
echo -e ""
echo -e "\e[94m  Exporting files from RRD to XML...\e[97m"
echo -e ""
cd ${TARGETDIR}
for f in `find . -name '*.rrd'`; do
    FILENAME=`basename -s .rrd $f`
    RELATIVEDIR=`dirname $f`
    rrdtool dump $f ${RELATIVEDIR}/$FILENAME.xml
    tar -rvf ${WORKDIR}/${PREFIX}${TIMESTAMP}.tar ${RELATIVEDIR}/$FILENAME.xml
    rm ${RELATIVEDIR}/${FILENAME}.xml
done
echo -e ""
echo -e "\e[94m  Compressing...\e[97m"
echo -e ""
gzip ${WORKDIR}/${PREFIX}${TIMESTAMP}.tar
echo -e "\e[93m  done...archive created: ${WORKDIR}/${PREFIX}${TIMESTAMP}.tar.gz\e[97m"
echo -e ""
}

function restore {

FILELIST=`find ${WORKDIR} -name ${PREFIX}'*.tar.gz'`
if [[ -z "${FILELIST}" ]]; then
    echo -e "\e[91m  No available files to restore!\e[97m"
    return 1
fi
FILELIST=(${WORKDIR}/${PREFIX}*.tar.gz)
echo -e ""
echo -e "\e[93m  Select a file to be restored:\e[97m"
echo -e ""
select archive in ${FILELIST[@]} "Cancel"; do
       if [[ "${archive}" == "Cancel" ]]; then
           return 0
       fi
       if [[ "${archive}" ]]; then
           break
       fi
done
if [[ ! -d "${TARGETDIR}" ]] ; then
    echo -e "\e[91m  Missing destination directory!\e[97m"
    return 1
fi
echo -e ""
echo -e "\e[94m  Extracting files in temporary directory...\e[97m"
echo -e ""
mkdir -p /tmp/${TIMESTAMP}
cd /tmp/${TIMESTAMP}
tar -zxvf ${archive}
echo -e ""
echo -e "\e[94m  Importing files from XML to RRD...\e[97m"
echo -e ""
for f in `find . -name '*.xml'`; do
    FILENAME=`basename -s .xml $f`
    RELATIVEDIR=`dirname $f | sed -e "s/^\.\///"`
    echo ${TARGETDIR}/${RELATIVEDIR}/${FILENAME}".rrd"
    rrdtool restore -f $f ${TARGETDIR}/${RELATIVEDIR}/${FILENAME}.rrd
    rm $f
done
echo -e ""
echo -e "\e[93m  cleaning temporary directory...\e[97m"
echo -e ""
rm -r /tmp/${TIMESTAMP}
#################################################
# Comment following line if you want to keep    #
# archive after a successful restoring          #
#################################################
rm ${archive}
echo -e "\e[93m  done...${archive} has been restored\e[97m"
echo -e ""
}

function transfer {

FILELIST=`find ${WORKDIR} -name ${PREFIX}'*.tar.gz'`
if [[ -z "${FILELIST}" ]]; then
    echo -e "\e[91m  No available files to transfer!\e[97m"
    return 1
fi
FILELIST=(${WORKDIR}/${PREFIX}*.tar.gz)
echo -e ""
echo -e "\e[93m  Select a file to be transferred:\e[97m"
echo -e ""
select archive in ${FILELIST[@]} "Cancel"; do
       if [[ "${archive}" == "Cancel" ]]; then
           return 0
       fi
       if [[ "${archive}" ]]; then
           break
       fi
done
pendrive=(`ls -l /dev/disk/by-id/usb-*part? 2>/dev/null |  sed 's@.*/@@'`)
counter=0
if [[ "${pendrive}" ]]; then
     for f in "${pendrive[@]}"; do
         counter=$((counter + 1))
         if [[ `lsblk -n --output MOUNTPOINT /dev/$f` ]]; then
            mydisk[$counter]=`lsblk -n --output=MOUNTPOINT /dev/$f`
         fi
     done
fi
echo -e ""
echo -e "\e[93m  "${archive}" has been selected for transfer."
echo -e "  Choose a destination:\e[97m"
echo -e ""
select destination in ${mydisk[@]} "SCP Copy" "Cancel"; do
       if [[ "${destination}" == "Cancel" ]]; then
           return 0
       fi
       if [[ "${destination}" ]]; then
           break
       fi
done
echo -e ""
echo -e "\e[94m  Copying...\e[97m"
echo -e ""
if [[ "${destination}" == "SCP Copy" ]]; then
     scp ${archive} pi@${SCPMACHINE}:.
     else
     cp ${archive} ${destination}
fi
if [[ "$?" == 0 ]]; then
    echo -e ""
    echo -e "\e[93m  "${archive}" has been successfully transferred.\e[97m"
    echo -e ""
#################################################
# Comment following line if you want to keep    #
# archive after copy on pendrive/remote machine #
#################################################
    rm ${archive}
    else
    echo -e ""
    echo -e "\e[91m  Transfer failed!\e[97m"
    echo -e ""
fi
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

while true; do
      echo -e ""
      echo -e "\e[93m  Select operation:"
      echo -e ""
      echo -e "1) Backup"
      echo -e "2) Restore"
      echo -e "3) Transfer"
      echo -e "4) Exit\e[97m"
      read choice
      case $choice in
           1 ) backup;;
           2 ) restore;;
           3 ) transfer;;
           4 ) echo -e "\e[93m  Terminated by user\e[97m"; break;;
      esac
done
