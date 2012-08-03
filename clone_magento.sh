#!/bin/sh
#
#clone_magento.sh
#
#clones a magento installation, changes db entries and /app/etc/local.xml
#
#   IMPORTANT
#
#this script was written for my own purposes and is not tested against real world cases. 
#YOU SHOULD DEFINITELY TEST THIS ON A SANDBOX BEFORE USING IT IN REAL LIFE
#
#run this script from the source host
#
#environment:
# - virtualmin on source and destination
# - we run as root
 
#edit this file!
.clone_magento.vars
 
SRCURL=$SRCSUBDOMAIN.$DOMAIN
DSTURL=$DSTSUBDOMAIN.$DOMAIN
DSTHOST=$DSTURL
SRCDIR=/home/in-due/domains/$SRCURL/public_html
DSTDIR=/home/in-due/domains/$DSTURL/public_html
DSTDBHOST=$DSTHOST
SRCDB=$SRCSUBDOMAIN
DSTDB=$DSTSUBDOMAIN
 
#ACTION!
 
ssh $DSTHOST virtualmin create-domain --domain $DSTURL --parent $DOMAIN --shared-ip $DSTIP --dir --webmin --web --mail --mysql
ssh $DSTHOST virtualmin create-user --domain $DSTURL --user ftp --pass $PASSWORD --web --mysql $DSTDB
 
#transfer files
rsync -a $SRCDIR/ $DSTHOST:$DSTDIR/
 
#transfer db
#as we did create the destination domain via virtualmin, we assume that it exists
mysqldump --single-transaction --quick -u root --password=$SRCDBROOTPW $SRCDB |ssh $DSTDBHOST mysql -f -u root --password=$DSTDBROOTPW $DSTDB
 
#change db
ssh $DSTDBHOST mysql -u root --password=$DSTDBROOTPW $DSTDB <<EOFMYSQL
update core_config_data set value = 'http://$DSTURL/' where path = 'admin/url/custom';
update core_config_data set value = 'http://$DSTURL/' where path = 'web/unsecure/base_url';
update core_config_data set value = 'https://$DSTURL/' where path = 'web/secure/base_url';
truncate core_session;
EOFMYSQL
 
#change /app/etc/local.xml, what a hack.. use xmlstarlet ed -u -L on newer versions of xmlstarlet (note to self: learn bash scripting)
cp $DSTDIR/app/etc/local.xml $DSTDIR/app/etc/local.xml.edit
xmlstarlet ed -u "//config/global/resources/default_setup/connection/username" -v <![CDATA[ftp.$DSTSUBDOMAIN]]> $DSTDIR/app/etc/local.xml.edit >$DSTDIR/app/etc/local.xml
cp $DSTDIR/app/etc/local.xml $DSTDIR/app/etc/local.xml.edit
xmlstarlet ed -u "//config/global/resources/default_setup/connection/password" -v <![CDATA[$PASSWORD]]> $DSTDIR/app/etc/local.xml.edit >$DSTDIR/app/etc/local.xml
cp $DSTDIR/app/etc/local.xml $DSTDIR/app/etc/local.xml.edit
xmlstarlet ed -u "//config/global/resources/default_setup/connection/host" -v <![CDATA[$DSTDBHOST]]> $DSTDIR/app/etc/local.xml.edit >$DSTDIR/app/etc/local.xml
cp $DSTDIR/app/etc/local.xml $DSTDIR/app/etc/local.xml.edit
xmlstarlet ed -u "//config/global/resources/default_setup/connection/dbname" -v <![CDATA[$DSTDB]]> $DSTDIR/app/etc/local.xml.edit >$DSTDIR/app/etc/local.xml
rm $DSTDIR/app/etc/local.xml.edit
 
#clean up
ssh $DSTHOST rm -rf $DSTDIR/var/cache
ssh $DSTHOST rm -rf $DSTDIR/downloader/pearlib/pear.ini
 
#notify
echo "All done." | mail $ADMIN -s "magento shop at $SRCURL cloned to $DSTURL"