#!/usr/bin/env bash
openssl ecparam -name prime256v1 -genkey -noout -outform PEM -out private.key
openssl req -new -keyform PEM -key private.key -out csr.pem -subj "/C=SG/ST=Singapore/L=Singapore/O=Secure/OU=Secure/CN=192.168.1.10"
openssl x509 -req -days 1825 -in csr.pem -CAform PEM -CA root-ca.crt -CAkey root-ca.key -CAcreateserial -outform PEM -out certificate.crt -sha256
openssl x509 -outform der -in root-ca.crt -out root-ca.der
cat root-ca.crt > ca_bundle.crt
cat certificate.crt root-ca.crt > cert_chain.crt
