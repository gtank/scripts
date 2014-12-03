#!/bin/bash

WORKDIR=$(pwd)
OUTDIR=$WORKDIR/output
EFITOOLS=$WORKDIR/efitools
SHIM=$WORKDIR/shim
GRUB=$WORKDIR/grub

ROOT=CoreOS-Boot-CA
SIGNER=CoreOS-Boot-Signer
DAYS=3650
QEMUHACK=true

# housekeeping

if ls *.key 1> /dev/null 2>&1; then
  echo "===================="
  echo "Have you already run this script? Continuing will erase everything!"
  echo "===================="

  read -r -p "Are you sure? [y/N] " response
  if [[ ! $response =~ ^([yY][eE][sS]|[yY])$ ]]
  then
    exit
  fi
fi

rm -r $ROOT.* $SIGNER.* signed $OUTDIR
mkdir -p $OUTDIR

# clone the necessary tools
git clone git://git.kernel.org/pub/scm/linux/kernel/git/jejb/efitools.git
git clone https://github.com/mjg59/shim.git
git clone https://github.com/coreos/grub.git

# generate our internal key hierarchy
echo "CA request"
openssl req -x509 -nodes -newkey rsa:2048 -out $ROOT.crt -keyout $ROOT.key -days $DAYS

# shim's embedded certs are DER
openssl x509 -in $ROOT -outform DER -out $ROOT

if $QEMUHACK; then
  ruby qemuhack.rb
fi
echo 01 > $ROOT.srl
touch $ROOT.idx
mkdir signed

echo "Signer request"
openssl req -nodes -newkey rsa:2048 -keyout $SIGNER.key -out $SIGNER.req
openssl ca -config config/$ROOT.cnf -extensions codesigning -in $SIGNER.req -out $SIGNER.crt


# now the secure boot stuff
cd $EFITOOLS
make clean

# new UEFI keys
for key in PK KEK DB; do
  openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Demo $key/" -keyout $key.key -out $key.crt -days $DAYS -nodes -sha256
  cp $key.key $OUTDIR/$key.key
  cp $key.crt $OUTDIR/$key.crt
done

make
cp LockDown.efi $OUTDIR/lockdown.efi

# build shim with our new cert
cd $SHIM
make clean
git apply $WORKDIR/ubuntu_build_fix.patch
make VENDOR_CERT_FILE=$WORKDIR/$ROOT.cer
sbsign --key $OUTDIR/DB.key --cert $OUTDIR/DB.crt --output shim.signed.efi shim.efi
cp shim.signed.efi $OUTDIR/
