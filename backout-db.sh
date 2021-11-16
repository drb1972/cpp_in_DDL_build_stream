#!/usr/bin/ksh93
#
# backout-db.sh
# =============
# Backout script for a CLPPlus deployment
# (suitable for z/OS or LUW)
#
# Parameters
# ----------
# 1 : Connection location (z/OS)
# 2 : Hostname
# 3 : Port number
# 4 : Connection ID
# 5 : Connection PW
# 6 : SQLID
# 7 : Database (z/OS)
# 8 : Storage group (z/OS)
# Notes
# -----
#

# Check that $DB2_HOME is set
if [ -z "$DB2_HOME" ]
then
  echo "Run db2profile to set up DB2 environment"
  exit 8;
else
  echo "DB2 environment set correctly"
fi

#
# Check for inputs
#
if [ $# = 8 ]; then
  echo "Eight arguments passed";
  location="$1";
  host="$2";
  portnum="$3";
  userid="$4";
  pword="$5";
  sqlid="$6";
  zosdb="$7";
  zossg="$8";
else
  #
  # If no inputs then prompt
  #
  echo "Unexpected number of arguments passed : prompting for data";
  print -n "Connection location (z/OS): ";read location;
  print -n "Enter hostname: ";read host;
  print -n "Enter port number: "; read portnum;
  print -n "Enter connection user ID: "; read userid;
  # Do not echo password to screen
  stty -echo;print -n "Enter connection password: "; read pword;stty echo;printf "\n";
  print -n "Enter current SQLID: "; read sqlid;
  print -n "Database (for z/OS tablespaces): "; read zosdb;
  print -n "STOGROUP (for z/OS tablespaces): "; read zossg;
fi


#
# z/OS deployment : add license JAR
#
export CLASSPATH=$CLASSPATH:./db2jcc_license_cisuz.jar;

# Check operating system
os=`uname`;
echo "Running on $os";

# Make various details upper case
location=$(echo $location|tr "[:lower:]" "[:upper:]");
sqlid=$(echo $sqlid|tr "[:lower:]" "[:upper:]");
zosdb=$(echo $zosdb|tr "[:lower:]" "[:upper:]");
zossg=$(echo $zossg|tr "[:lower:]" "[:upper:]");

#
# Check  location name
#
if echo $location | egrep -q '^(T|P)[1-4]EDBGH$'
then
  echo "Location Name Good";
else
  echo "Bad location name : standard is (T|P)nEDBGH";exit 8;
fi

# Check port number is five digits
if echo $portnum | egrep -q '^[0-9]{5}$'
then
  echo "Port number good";
else
  echo "Bad port number";
  exit 8;
fi

#
# Check schema (SQLID)
#
if echo $sqlid | egrep -q '^(TDB[1-4]DV[B-J][0-2]|PDB[1-4]PJS[0-2])$'
then
  echo "Schema (SQLID) good";
else
  echo "Bad schema name : standard is TDBnDVe0 (dev) or PDBnPJS0 (prod)";exit 8;
fi

# Set schema name to current SQLID
schema=$sqlid;
echo $schema;
#
# Set environment variable for use in CLP*PLUS
#
export DB2SQLID=$sqlid;

#
# Now prepare to use CLPPlus
#
export DB2DSDRIVER_CFG_PATH=`pwd`;

# echo `db2 get dbm cfg|grep SSL_SVCENAME`;

#
# Check valid z/OS database / stogroup names
#
# Checks to add
#
# 1) Second letter of database and STOGROUP must match
# 2) If TDB1DV<x> then D<x><eee><nnn> and G<x><eee><nnn>
# 3) If PDB<n>PJS) then DP<eee><nnn> and GP<eee><nnn>

cp db2dsdriver.cfg.template db2dsdriver.cfg

sed -i 's/$DBALIAS/'$location'/g' db2dsdriver.cfg
sed -i 's/$LOCATION/'$location'/g' db2dsdriver.cfg
sed -i 's/$DBHOST/'$host'/g' db2dsdriver.cfg
sed -i 's/$DBPORT/'$portnum'/g' db2dsdriver.cfg
sed -i 's/$USERID/'$userid'/g' db2dsdriver.cfg
sed -i 's/$PASSWORD/'$pword'/g' db2dsdriver.cfg

##########################################################
### TYPICALLY DEVELOPERS DO NOT CHANGE ABOVE THIS LINE ###
##########################################################

#
# Copy template files to executable versions
#
cp vea-drop-t0010-template.sql vea-drop-t0010.sql
cp vea-drop-t0020-template.sql vea-drop-t0020.sql

#
# Now use sed to swap in appropriate database and storage group names for z/OS
#

sed -i 's/$DBNAME/'$zosdb'/g' vea-drop-t0010.sql
#sed -i 's/$SGNAME/'$zossg'/g' vea-drop-t0010.sql
sed -i 's/$DBNAME/'$zosdb'/g' vea-drop-t0020.sql
#sed -i 's/$SGNAME/'$zossg'/g' vea-drop-t0020.sql

clpplus -nw $userid@$location @backout.clpplus

rm db2dsdriver.cfg

rm vea-drop-t0010.sql
rm vea-drop-t0020.sql
