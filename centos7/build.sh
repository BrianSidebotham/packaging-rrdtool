#!/bin/sh

basedir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
builddir=${basedir}/build

# The version of Ruby to build
rrdtool_version=1.7.2
rrdtool_url="https://oss.oetiker.ch/rrdtool/pub/rrdtool-${rrdtool_version}.tar.gz"

# Go crazy and get the whole development tool set
yum group install -y "Development Tools"
yum install -y wget openssl-devel zlib-devel cmake libicu-devel readline-devel gdbm-devel pango-devel libxml2-devel librados2-devel perl-DBI libdbi-devel libpng12-devel freetype-devel fontconfig-devel pixman-devel

wget -P ${builddir} ${rrdtool_url}
if [ "$?" -ne 0 ]; then
    echo "ERROR: Could not download from ${rrdtool_url}" >&2
    exit 1
fi

cd ${builddir} && tar xf rrdtool-${rrdtool_version}.tar.gz
if [ $? -ne 0 ]; then
    echo "ERROR: Could not extract the source code" >&2
    exit 1
fi

cd ${builddir}/rrdtool-${rrdtool_version}
./configure --prefix /opt/rrdtool --disable-perl
if [ $? -ne 0 ]; then
    echo "ERROR: Could not configure the rrdtool build" >&2
    exit 1
fi

# Build is knackered, so modify the Makefile to prevent trying to build a non-existent doc
sed -i 's/am__append_2 = rrdrados.pod/#am__append_2 = rrdrados.pod/' ${builddir}/rrdtool-${rrdtool_version}/doc/Makefile

make -j $(nproc)

if [ $? -ne 0 ]; then
    echo "ERROR: Could not build rrdtool" >&2
    exit 1
fi

# Put ruby in place, but into the temporary install location
make install

if [ $? -ne 0 ]; then
    echo "ERROR: Could not install rrdtool into packaging dir" >&2
    exit 1
fi

echo "DONE WITH CURRENT BUILD"
exit 0

oxidized_version=$(/opt/oxidized/bin/oxidized --version)

mkdir -p -m 755 ${installdir}/INSTALL/oxidized-${oxidized_version}/opt
mv /opt/oxidized ${installdir}/INSTALL/oxidized-${oxidized_version}/opt/

mkdir -p -m 755 ${installdir}/INSTALL/oxidized-${oxidized_version}/usr/lib/systemd/system

cat << EOF > ${installdir}/INSTALL/oxidized-${oxidized_version}/usr/lib/systemd/system/oxidized.service
[Unit]
Description=Oxidized Network Configuration Manager
After=syslog.target network.target

[Service]
Environment=OXIDIZED_HOME=/opt/oxidized
ExecStart=/opt/oxidized/bin/oxidized

[Install]
WantedBy=multi-user.target
EOF

mkdir -p -m 755 ${installdir}/SOURCES
cd ${installdir}/INSTALL
tar czf "${installdir}/SOURCES/oxidized-${oxidized_version}.tar.gz" *

cp -r ${basedir}/SPECS ${installdir}/
rpmbuild --define "_topdir ${installdir}" -ba "${installdir}/SPECS/oxidized.spec"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build RPM" >&2
    exit 1
fi
