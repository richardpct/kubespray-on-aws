#!/usr/bin/env bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

apt-get update
apt-get upgrade -y
apt-get install -y \
  nvme-cli \
  open-iscsi \
  vim

echo ${ssh_key} >> /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

mkdir /var/lib/longhorn
longhorn_disk=''

for disk in $(nvme list | awk '/nvme/{print $1}'); do
  if ! blkid $disk > /dev/null 2>&1; then
    longhorn_disk=$disk
    break
  fi
done

if [ $longhorn_disk == '' ]; then
  echo 'No additional disk found'
  exit 1
fi

mkfs.ext4 $longhorn_disk
tune2fs -L "longhorn" $longhorn_disk
echo 'LABEL=longhorn    /var/lib/longhorn    ext4    defaults    0 0' >> /etc/fstab
mount /var/lib/longhorn

echo 'Done'
