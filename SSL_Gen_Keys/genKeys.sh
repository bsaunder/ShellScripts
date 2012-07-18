###############################
#  SSL Key Generation Script  #
#  Bryan Saunders             #
#  bsaunder@redhat.com        #
###############################
echo "SSL Generation Script"

echo "Checking for OpenSSL and Keytool"
CMDS="openssl keytool"
for c in $CMDS
do
	type -P $c &>/dev/null  && continue  || { echo "$c command not found."; exit 1; }
done
echo "OpenSSL and Keytool found"

echo "Reading ssl.properties..."
. ./ssl.properties
echo "Properties Set."

echo "What password should be used with certificates/keystores (min 6 chars)?"
read password
echo "Please Enter $password ANYTIME You are prompted for a password"

echo "Generating Self-Signed Server Certificate"

echo "Preparing..."
rm -rf server
rm -rf clients

# Generate Server Certiicate
echo "Generating Server Certificates..."

echo "Generating RSA Key..."
openssl genrsa -out server-private-key.pem 2048

echo "Signing Certificate, Server: /C=$country/ST=$state/L=$city/O=$org/OU=$orgUnit/CN=$server"
openssl req -new -x509 -key server-private-key.pem -out server-certificate.pem -days 365 -subj "/C=$country/ST=$state/L=$city/O=$org/OU=$orgUnit/CN=$server"

echo "Generating PKCS12 Keystore..."
openssl pkcs12 -export -out server-keystore.pkcs12 -in server-certificate.pem -inkey server-private-key.pem -passout pass:$password

echo "Generating JKS Keystore..."
keytool -importkeystore -srckeystore server-keystore.pkcs12 -srcstoretype PKCS12 -destkeystore server-keystore.jks -deststoretype JKS -storepass $password -keypass $password << EOF
$password
EOF

# Generate Client Certiicates
if [ $clientCount -gt 0 ]; then
	echo "Generating Client Certificates..."
	mkdir clients

	i="1"
	while [ $i -le $clientCount ]; do
		echo "Generating Client $i Certificates..."
		clientPath=clients/client_$i/

		echo "Generating RSA Key"
		openssl genrsa -out client_$i-private-key.pem 2048

		clientHostname=client_$i
		echo "Signing Certificate, Client: /C=$country/ST=$state/L=$city/O=$org/OU=$orgUnit/CN=${!clientHostname}"
		openssl req -new -x509 -key client_$i-private-key.pem -out client_$i-certificate.pem -days 365 -subj "/C=$country/ST=$state/L=$city/O=$org/OU=$orgUnit/CN=${!clientHostname}"

		echo "Generating Client Trust Store..."
		keytool -importcert -trustcacerts -keystore  client_$i-truststore.jks -storetype jks -storepass $password -file server-certificate.pem << EOF
yes
EOF

		echo "Adding Client to Server Trust Store"
		keytool -importcert -trustcacerts -keystore  server-truststore.jks -storetype jks -storepass $password -alias client_$i -file client_$i-certificate.pem << EOF
yes
EOF

		echo "Generating PKCS12 Keystore..."
		openssl pkcs12 -export -out client_$i-keystore.pkcs12 -inkey client_$i-private-key.pem -in client_$i-certificate.pem -passout pass:$password 

		echo "Generating JKS Keystore..."
		keytool -importkeystore -srckeystore client_$i-keystore.pkcs12 -srcstoretype PKCS12 -destkeystore client_$i.jks -deststoretype JKS -storepass $password -keypass $password << EOF
$password
EOF

		echo "Cleaning Up Client Certs..."
		rm client_$i-private-key.pem
		rm client_$i-certificate.pem
		rm client_$i-keystore.pkcs12

		mkdir $clientPath
		mv client_$i-truststore.jks $clientPath
		mv client_$i.jks $clientPath
		

		i=$[$i+1]
	done
fi

echo "Cleaning Up Server Cert..."
rm server-private-key.pem
rm server-certificate.pem
rm server-keystore.pkcs12

mkdir server
mv server-keystore.jks server/
mv server-truststore.jks server/

echo "Certificates Created. All Passwords are: $password"

exit 0
