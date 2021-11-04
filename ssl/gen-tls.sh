#!/bin/bash

openssl genrsa 2048 > server.key
openssl req -new -key server.key <<EOF > server.csr
JP
My Prefecture
My City
My Company
My Section
myhost



EOF
openssl x509 -days 3650 -req -signkey server.key < server.csr > server.crt

