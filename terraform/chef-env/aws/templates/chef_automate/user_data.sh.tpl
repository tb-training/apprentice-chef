# Download profiles for Audit cookbook

download_compliance_profiles() {
    for PROFILE in \
        linux-baseline \
        cis-centos7-level1 \
        cis-ubuntu16.04lts-level1-server \
        windows-baseline \
        cis-windows2012r2-level1-memberserver \
        cis-windows2016-level1-memberserver \
        cis-windows2016rtm-release1607-level1-memberserver \
        cis-rhel7-level1-server \
        cis-sles11-level1 
    do 
        echo "$PROFILE" 
        VERSION=`curl -s -k -H "api-token: $TOKEN" https://${var_automate_hostname}/api/v0/compliance/profiles/search  -d "{\"name\":\"$PROFILE\"}" | /snap/bin/jq -r .profiles[0].version`

        echo "Version:  $VERSION" 
        curl -s -k -H "api-token: $TOKEN" -H "Content-Type: application/json" 'https://${var_automate_hostname}/api/v0/compliance/profiles?owner=admin' \
            -d  "{\"name\":\"$PROFILE\",\"version\":\"$VERSION\"}"
        echo
        echo
    done
}


install_a2() { 
    sudo snap install jq
    sudo hostnamectl set-hostname ${var_automate_hostname} 
    sudo sysctl -w vm.max_map_count=262144 
    sudo sysctl -w vm.dirty_expire_centisecs=20000
    sudo mkdir -p /etc/chef-automate 
    curl https://packages.chef.io/files/${var_channel}/latest/chef-automate-cli/chef-automate_linux_amd64.zip |gunzip - > chef-automate && chmod +x chef-automate
#      "sudo chmod +x /tmp/install_chef_automate_cli.sh",
#      "sudo bash /tmp/install_chef_automate_cli.sh", 
    sudo ./chef-automate init-config --file /tmp/config.toml $(if ${var_automate_custom_ssl}; then echo '--certificate /tmp/ssl_cert --private-key /tmp/ssl_key'; fi)
    sudo sed -i 's/fqdn = \".*\"/fqdn = \"${var_automate_hostname}\"/g' /tmp/config.toml
    sudo sed -i 's/channel = \".*\"/channel = \"${var_channel}\"/g' /tmp/config.toml
    sudo sed -i 's/license = \".*\"/license = \"${var_automate_license}\"/g' /tmp/config.toml
#     "sudo rm -f /tmp/ssl_cert /tmp/ssl_key",

    sudo mv /tmp/config.toml /etc/chef-automate/config.toml 
    sudo ./chef-automate deploy /etc/chef-automate/config.toml --product automate --product chef-server --product builder --accept-terms-and-mlsa
#      "sudo ./chef-automate applications enable", 

#    sudo ./chef-automate config patch /tmp/automate-eas-config.toml
}


create_infra_users() { 
    sudo chef-server-ctl user-create ${var_chef_user1} chef user ${var_chef_user1}@chef.io '1234chefabcd' --filename $HOME/${var_chef_user1}.pem
    sudo chef-server-ctl org-create ${var_chef_organization} 'automate' --association_user ${var_chef_user1}  --filename $HOME/${var_chef_organization}-validator.pem
}


create_a2_users() {
    echo "xxxxx Add Automate Users xxxxx"
    export TOKEN=`sudo chef-automate admin-token`
    echo $TOKEN
    for i in {1..10}
    do
        USERNAME="workstation-$i"
        echo "creating user $USERNAME"
	curl -k -H "api-token: $TOKEN" -H "Content-Type: application/json" https://${var_automate_hostname}/api/v0/auth/users?pretty \
        --data "{\"name\":\"$USERNAME\", \"username\":\"$USERNAME\", \"password\":\"workstation!\"}"
    done
}

output_information() {
    echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx Client PEM xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" 
    sudo cat $HOME/${var_chef_user1}.pem
    echo
    echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx Validator PEM xxxxxxxxxxxxxxxxxxxxxxxxxxxx" 
    sudo cat $HOME/${var_chef_organization}-validator.pem
 
    sudo chown ubuntu:ubuntu $HOME/automate-credentials.toml 
    sudo echo -e \"api-token =\" $TOKEN >> $HOME/automate-credentials.toml
    sudo cat $HOME/automate-credentials.toml
}

# TOKEN is somewhat global var
# created in create_a2_users
# used in download_compliance_profiles,output_information
# 
install_a2
sleep 60
create_a2_users
create_infra_users
download_compliance_profiles
output_information

