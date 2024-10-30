#!/usr/bin/env bash

set -x -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

function install_packages() {
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y \
    unzip \
    git \
    vim \
    jq \
    python3.9-venv
  update-alternatives --install /usr/bin/python python /usr/bin/python3.9 20
  update-alternatives --install /usr/bin/python3 python /usr/bin/python3.9 20
}

function install_awscli() {
  if [ ${archi} == 'arm64' ]; then
    ARCH='aarch64'
  else
    ARCH='x86_64'
  fi

  cd /root
  curl "https://awscli.amazonaws.com/awscli-exe-linux-$ARCH.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  rm awscliv2.zip
}

function associate_eip() {
  TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
  INSTANCE_ID="$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)"
  aws --region ${region} ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${eip_bastion_id}
}

function deploy_kubespray() {
  sleep 5
  cd /home/ubuntu
  git clone -b ${kubespray_vers} https://github.com/kubernetes-sigs/kubespray.git
  VENVDIR=kubespray-venv
  KUBESPRAYDIR=kubespray
  python3 -m venv $VENVDIR
  source $VENVDIR/bin/activate
  cd $KUBESPRAYDIR
  echo 'ansible-core==2.14.11' >> requirements.txt
  pip install -U -r requirements.txt
  pip install ruamel_yaml

  while [[ $(aws ec2 describe-instances --filters "Name=tag:Name,Values=kubernetes master" | jq '.Reservations[].Instances[].PrivateIpAddress' | grep 192 | wc -l) -ne 3 ]]; do
    sleep 5
  done

  while [[ $(aws ec2 describe-instances --filters "Name=tag:Name,Values=kubernetes worker" | jq '.Reservations[].Instances[].PrivateIpAddress' | grep 192 | wc -l) -ne 3 ]]; do
    sleep 5
  done

  MASTER_NODES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kubernetes master" | jq '.Reservations[].Instances[].PrivateIpAddress' | grep 192 | sed -e 's/"//g')
  WORKER_NODES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kubernetes worker" | jq '.Reservations[].Instances[].PrivateIpAddress' | grep 192 | sed -e 's/"//g')
  echo $MASTER_NODES
  echo $WORKER_NODES

  cp -rfp inventory/sample inventory/mycluster
  declare -a IPS=($MASTER_NODES $WORKER_NODES)
  CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py $${IPS[@]}
  sed -i -e '34,36d' inventory/mycluster/hosts.yaml
  sed -i -e '32i\ \ \ \ \ \ \ \ node3:' inventory/mycluster/hosts.yaml
  sed -i -e 's/## apiserver_loadbalancer_domain_name: "elb.some.domain"/apiserver_loadbalancer_domain_name: "${kube_api_internet}"/' inventory/mycluster/group_vars/all/all.yml
  sed -i -e 's/helm_enabled: false/helm_enabled: true/' inventory/mycluster/group_vars/k8s_cluster/addons.yml
  sed -i -e 's/metrics_server_enabled: false/metrics_server_enabled: true/' inventory/mycluster/group_vars/k8s_cluster/addons.yml
  sed -i -e 's/ingress_nginx_enabled: false/ingress_nginx_enabled: true/' inventory/mycluster/group_vars/k8s_cluster/addons.yml
  chown -R ubuntu:ubuntu /home/ubuntu/$KUBESPRAYDIR
  echo "${ssh_key}" > /home/ubuntu/.ssh/id_ed25519
  chmod 600 /home/ubuntu/.ssh/id_ed25519
  chown ubuntu:ubuntu /home/ubuntu/.ssh/id_ed25519
  #TODO: improve that
  sleep 60
  su - ubuntu -c 'source kubespray-venv/bin/activate && cd kubespray && ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml'
}

function get_kubeconfig() {
  MASTER1=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kubernetes master" | jq '.Reservations[].Instances[].PrivateIpAddress' | grep 192.168.0 | sed -e 's/"//g')
  mkdir /home/ubuntu/.kube
  su - ubuntu -c "ssh -o StrictHostKeyChecking=accept-new ubuntu@$MASTER1 'sudo cat /etc/kubernetes/admin.conf'" > /home/ubuntu/.kube/config
  chown ubuntu:ubuntu /home/ubuntu/.kube/config
  chmod 600 /home/ubuntu/.kube/config
}

install_packages
install_awscli
associate_eip
deploy_kubespray
get_kubeconfig

echo "Done"
