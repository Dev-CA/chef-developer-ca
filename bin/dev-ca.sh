#!/bin/bash

set -e

cd `ls *devca`

COMMAND=$1
shift

DOMAIN=$1
shift

CA_NAME=${PWD##*/}

if [[ "$COMMAND" == "init" ]]; then
  # generate a root certifacate
  openssl genrsa -out $CA_NAME.key 2048
  openssl req -x509 -new -nodes -key $CA_NAME.key -days 1024 -out $CA_NAME.pem
  exit 0
fi

if [[ "$COMMAND" != "new" ]]; then
  cat <<USAGE
Available commands:

dev-ca init
  Initializes a new certifacation authority by creating a new
  root certifate. Before running this command, first create a
  local directory with a name ending in "devca". This directory
  will be used to store the generated certifacation authority
  files and the name of the directory will be used as an Org
  name for the certificates.

dev-ca new <domain> [alt-names]
  Creates new certificate chain and private key for the specified
  domain. The alt-names list can contain one or more alternative
  names for the domain (e.g. sub-domains).

USAGE

  exit 1
fi

openssl genrsa -out $DOMAIN.privkey.pem 2048
cat > $DOMAIN.cfg <<EOF
[ req ]
prompt = no
req_extensions = v3_req
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
C = US
ST = Earth
L = Earth
O = $CA_NAME
OU = IT
CN = *.$DOMAIN
emailAddress = admin@$DOMAIN

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN

# Nested wildcards are not supported by most browsers nowadays, but they might get supported in the future:
# http://security.stackexchange.com/questions/10538/what-certificates-are-needed-for-multi-level-subdomains
DNS.3 = *.*.$DOMAIN
DNS.4 = *.*.*.$DOMAIN
EOF

next_altname=5

# Add SAN records for any subdomains passed on the command line
for arg in "$@"
do
    echo "DNS.$next_altname = $arg.$DOMAIN" >> $DOMAIN.cfg
    echo "DNS.$((next_altname + 1)) = *.$arg.$DOMAIN" >> $DOMAIN.cfg
    next_altname=$((next_altname + 2))
done

openssl req -config $DOMAIN.cfg -new -sha256 -key $DOMAIN.privkey.pem -out $DOMAIN.csr
openssl ca -config $CA_NAME.cnf -policy signing_policy -extensions signing_req -notext -out $DOMAIN.temp.crt -infiles $DOMAIN.csr

# Uncomment to print out request and certificate info
# openssl req -text -noout -verify -in $DOMAIN.csr
# openssl x509 -in $DOMAIN.crt -text -noout

cat $DOMAIN.temp.crt $CA_NAME.crt > $DOMAIN.fullchain.pem
rm $DOMAIN.temp.crt $DOMAIN.cfg $DOMAIN.csr

mv $DOMAIN.fullchain.pem $DOMAIN.privkey.pem ../

