# Create a root certificate and private key to sign the certificates for your services
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=GCPX Organization /CN=gcpx.org' -keyout gcpx.org.key -out gcpx.org.crt
# Create a certificate and a private key for asm.gcpx.org
openssl req -out asm.gcpx.org.csr -newkey rsa:2048 -nodes -keyout asm.gcpx.org.key -subj "/CN=asm.gcpx.org/O=GCPX Organization"
openssl x509 -req -days 365 -CA gcpx.org.crt -CAkey gcpx.org.key -set_serial 0 -in asm.gcpx.org.csr -out asm.gcpx.org.crt
# Create a tls secret for istio-ingressgateway at NS:asm-gateway
kubectl create -n asm-test secret tls asm-gcpx-org-credential --key=asm.gcpx.org.key --cert=asm.gcpx.org.crt
