FROM coderus/sailfishos-platform-sdk-base
MAINTAINER Andrey Kozhevnikov <coderusinbox@gmail.com>

COPY progs/* /usr/local/bin/
COPY build.sh /usr/local/bin/

USER root
WORKDIR /root

RUN set -ex ;\
  chmod +x /usr/local/bin/* ;\
  test -f /usr/bin/atruncate || zypper -n in atruncate ;\
  test -f /usr/sbin/lvcreate || zypper -n in lvm2 ;\
  test -f /usr/bin/pigz || zypper -n in pigz

ENTRYPOINT ["/usr/local/bin/build.sh"]