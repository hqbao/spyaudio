#!/usr/bin/env bash
openssl ecparam -name prime256v1 -genkey -noout -outform PEM -out root-ca.key
openssl req -new -keyform PEM -key root-ca.key -out root-ca-csr.pem -subj "/C=SG/ST=Singapore/L=Singapore/O=TrustWorld/OU=TrustWorld/CN=TrustWorld"
openssl x509 -req -days 3650 -in root-ca-csr.pem -signkey root-ca.key -CAcreateserial -outform PEM -out root-ca.crt -sha256
