#!/bin/bash

# ---------------------------------------------------------------
#                         Config
#                  Edit the values below
# ---------------------------------------------------------------
SERVER="ad.example.com"
BASEDN="dc=example,dc=com"
MACHANISM="GSSAPI"
PORT="389"
DAYS=90;
ADMIN="admin"
PASSWORDLENGHT=8
# ---------------------------------------------------------------
#                     Global Variables
# ---------------------------------------------------------------
HOSTNAME=`hostname -s`
let "seconds_per_day = 60 * 60 * 24"
let "expiration = $(date +%s) + ${DAYS} * ${seconds_per_day}";
let "ldap_time = ($expiration + 11644473600) * 10000000";
newPassword=$(openssl rand -base64 ${PASSWORDLENGHT})
# ---------------------------------------------------------------
#                        Functions
# ---------------------------------------------------------------
function replace_attributes ()
{
    /usr/bin/ldapmodify -p ${PORT} -h ${SERVER} -Y ${MACHANISM} <<EOF
dn: $1
changetype: modify
replace: ms-Mcs-AdmPwdExpirationTime
ms-Mcs-AdmPwdExpirationTime: ${ldap_time}
-
replace: ms-Mcs-AdmPwd
ms-Mcs-AdmPwd: ${newPassword}
EOF
}

function add_attributes ()
{
    /usr/bin/ldapmodify -p ${PORT} -h ${SERVER} -Y ${MACHANISM} <<EOF
dn: $1
changetype: modify
add: ms-Mcs-AdmPwdExpirationTime
ms-Mcs-AdmPwdExpirationTime: ${ldap_time}
-
add: ms-Mcs-AdmPwd
ms-Mcs-AdmPwd: ${newPassword}
EOF
}

function reset_password ()
{
    /usr/bin/dscl . passwd /Users/${ADMIN} "${newPassword}"
}
# ---------------------------------------------------------------
#                          Main
# ---------------------------------------------------------------
# Generate our machine kerberos ticket used to authenticate towards Active
# Directory
/usr/bin/kinit -k ${HOSTNAME}$ 
# Set out internal field separator to break on newlines
IFS=$'\n';
# Query Active Directory for our machine and store dn and ms-Mcs-AdmPwdExpirationTime in an array
ldap_result=($(/usr/bin/ldapsearch -LLL -p ${PORT} -h ${SERVER} -Y ${MACHANISM} -b ${BASEDN} "(&(&(objectCategory=Computer)(sAMAccountName=${HOSTNAME}$)))" dn ms-Mcs-AdmPwdExpirationTime 2>/dev/null | /usr/bin/perl -p00e 's/\r?\n //g' | /usr/bin/awk -F ": " '($1 == "dn" || $1 == "ms-Mcs-AdmPwdExpirationTime") {print $2}'));

# Check if ms-Mcs-AdmPwdExpirationTime is defined
# if not add both ms-Mcs-AdmPwdExpirationTime and ms-Mcs-AdmPwd attributes and
# set a password for the local administrator account
# else check to see if the ms-Mcs-AdmPwdExpirationTime has expired, if so set
# new password and update the attributes
if [ -z ${ldap_result[1]} ]; then
    echo "LAPS does not exists"
    add_attributes ${ldap_result[0]}
    reset_password
else
    # Convert LDAP miliseconds to epoch
    let "epoch = (${ldap_result[1]} / 10000000) - 11644473600"
    if [ $(date +%s) -ge ${epoch} ]; then
        echo "LAPS expired - $(date +%s) - ${epoch}"
        replace_attributes ${ldap_result[0]}
        reset_password
    fi
fi
# Destroy our kerberos ticket
/usr/bin/kdestroy -p ${HOSTNAME}$
