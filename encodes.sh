#!/bin/bash

PW="NASPASSWD"
gdrive_recdir="GoogleDriveItemId"

querystring=$1

filepath=${querystring:9}

cd /tmp/

expect -c "
set timeout -1
spawn env LANG=ja_JP.UTF-8 /usr/bin/sftp conoha@"$(cat /var/www/html/ip/addresses/shiriuchi)":\"array1/Chinachu_REC/"${filepath}"\"

expect {
    \"Are you sure you want to continue connecting (yes/no)?\" {
        send \"yes\n\"
        exp_continue
    }
    \"Password:\" {
        send \""${PW}"\n\"
    }
}

expect eof
exit
"

fileName=${filepath##*/}
if [[ ! -f /tmp/$fileName ]]; then
    exit 2
fi

encodedFileName=${fileName%%.*}.mp4
/usr/local/bin/ffmpeg -i /tmp/$fileName \
                      -f mp4 \
                      -vsync 1 \
                      -vcodec libx265 \
                      -vf fieldmatch \
                      -s 1280x720 \
                      -aspect 16:9 \
                      -acodec copy \
                      -bsf:a aac_adtstoasc \
                      -map 0:0 \
                      -map 0:1 \
                      /tmp/$encodedFileName

if [[ ! -f /tmp/$encodedFileName ]]; then
    exit 3
fi

dirIdList=()
while read -r Id Name Type Size Created
do
    if [[ $Name = ${filepath%%/*} ]]; then
        dirIdList+=("$Id")
    fi
done < <(/usr/local/bin/gdrive -c /usr/share/httpd/.gdrive list --query \
    '"'${gdrive_recdir}'" in parents and trashed = false and name = "'${filepath%%/*}'"')

if [[ ${dirIdList[@]} -gt 1 ]]; then
    exit 4
fi

if [[ ${dirIdList[@]} -eq 0 ]]; then
    dirIdList+=$(/usr/local/bin/gdrive -c /usr/share/httpd/.gdrive mkdir --parent ${gdrive_recdir} ${filepath%%/*} | cut -d " " -f 2)
fi

/usr/local/bin/gdrive -c /usr/share/httpd/.gdrive upload --parent ${dirIdList[0]} $encodedFileName

exit 0