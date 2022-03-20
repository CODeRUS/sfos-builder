FROM coderus/sailfishos-platform-sdk-base
MAINTAINER Andrey Kozhevnikov <coderusinbox@gmail.com>

COPY progs/* /usr/bin/
COPY build.sh /usr/bin/

USER root
WORKDIR /root

RUN set -ex ;\
  chmod +x /usr/bin/* ;\
  test -f /usr/bin/atruncate || zypper -n in atruncate ;\
  test -f /usr/sbin/lvcreate || zypper -n in lvm2 ;\
  test -f /usr/bin/pigz || zypper -n in pigz ;\
  test -f /usr/sbin/modprobe || zypper -n in kmod ;\
  test -f /bin/grep || ln -s /usr/bin/grep /bin/grep

ENTRYPOINT ["/usr/bin/build.sh"]
