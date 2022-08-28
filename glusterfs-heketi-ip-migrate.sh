echo "Do you have heketi server installed on this server?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) migrate_heketi=true; break;;
        No ) migrate_heketi=false; break;;
    esac
done
echo "Stopping glusterd"
systemctl stop glusterd
if [ "$migrate_heketi" = true ] ; then
    echo "Stopping heketi server"
    systemctl stop heketi
    heketi db export --jsonfile=heketi-db.json --dbfile=/var/lib/heketi/heketi.db
fi
read -p "Please enter the number of nodes you need to migrate: " nodes
for node in $(eval echo "{1..$nodes}")
do
    read -p "Please enter old ip for node $node: " old_ip
    read -p "Please enter the new ip for node $node: " new_ip
    echo "Starting migration of old_ip: $old_ip to $new_ip"

    #Hostnames
    grep -rli "$old_ip" /var/lib/glusterd | xargs -i@ sed -i "s/$old_ip/$new_ip/g" @
    #Rename brick files
    find /var/lib/glusterd -name "*$old_ip*" -exec bash -c 'mv $0 ${0/'"$old_ip"'/'"$new_ip"'}' {} \;

    #If you have hosts file for dns naming uncomment this block
    # echo "$new_ip gluster$node" >> /etc/hosts

    echo "Finished renaming $old_ip to $new_ip"
    if [ "$migrate_heketi" = true ] ; then
        echo "Starting heketi db migration"
        sed -i "s/$old_ip/$new_ip/g" heketi-db.json
    fi
done
echo "Done migrating glusterfs ips"
if [ "$migrate_heketi" = true ] ; then
    echo "Reimporting heketi database"
    heketi db import --jsonfile=heketi-db.json --dbfile=/var/lib/heketi/heketi-new.db
    chown heketi:heketi /var/lib/heketi/heketi-new.db
    mv /var/lib/heketi/heketi.db heketi_old.db
    mv /var/lib/heketi/heketi-new.db /var/lib/heketi/heketi.db
    echo "Starting heketi"
    systemctl start heketi
fi
echo "Starting glusterd"
systemctl start glusterd