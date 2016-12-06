#!/bin/bash

set -e

cd `ls -d *devca`

COMMAND=$1
shift

CA_NAME=${PWD##*/}

if [[ "$COMMAND" == "init" ]]; then
  # generate a root certifacate
  openssl genrsa -out $CA_NAME.key 2048
  openssl req -x509 -new -nodes -key $CA_NAME.key -days 1024 -out $CA_NAME.crt

  touch index.txt
  echo 1A > serial.txt

  cat > $CA_NAME.cnf << EOF
HOME            = .
RANDFILE        = $ENV::HOME/.rnd

####################################################################
[ ca ]
default_ca = CA_default                 # The default ca section

[ CA_default ]
default_days = 1000                     # how long to certify for
default_crl_days = 30                   # how long before next CRL
default_md = sha256                     # use public key default MD
preserve = no                           # keep passed DN ordering

x509_extensions = ca_extensions         # The extensions to add to the cert

email_in_dn = no                        # Don't concat the email in the DN
copy_extensions = copy                  # Required to copy SANs from CSR to cert

base_dir    = .
certificate = $CA_NAME.crt    # The CA certifcate
private_key = $CA_NAME.key    # The CA private key
new_certs_dir = .             # Location for new certs after signing
database    = index.txt       # Database index file
serial      = serial.txt      # The current serial number

unique_subject  = no                    # Set to 'no' to allow creation of
                                        # several certificates with same subject.

####################################################################
[ req ]
default_bits        = 4096
default_keyfile     = $CA_NAME.key
distinguished_name  = ca_distinguished_name
x509_extensions     = ca_extensions
string_mask         = utf8only

####################################################################
[ ca_distinguished_name ]
countryName                 = Country Name (2 letter code)
countryName_default         = US

stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = Maryland

localityName                = Locality Name (eg, city)
localityName_default        = Baltimore

organizationName            = Organization Name (eg, company)
organizationName_default    = Test CA, Limited

organizationalUnitName      = Organizational Unit (eg, division)
organizationalUnitName_default = Server Research Department

commonName                  = Common Name (e.g. server FQDN or YOUR name)
commonName_default          = Test CA

emailAddress                = Email Address
emailAddress_default        = test@example.com

####################################################################
[ ca_extensions ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always, issuer
basicConstraints = critical, CA:true
keyUsage = keyCertSign, cRLSign

####################################################################
[ signing_policy ]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = optional
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

####################################################################
[ signing_req ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer

basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
EOF

  echo "$CA_NAME Initialized."
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

DOMAIN=$1
shift

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

