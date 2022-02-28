### Saifish OS image builder

## Prepare

```
docker build -t sfos-builder .
```

Grab your Jolla Store repo credentials from existing sailfish device:
```
cat /etc/ssu/ssu.ini
```

## Build

Check comments at the beginning of build.sh file for details

```
docker run --privileged --rm -it -v $PWD:/share -w /share -e RELEASE=4.3.0.15 -e USERNAME=ssu-ini-username -e PASSWORD=ssu-ini-password -e ARCH=armv7hl -e DEVICE=l500d -e DEVICE_VENDOR=qualcomm sfos-builder l500d-eu-lvm.ks
```