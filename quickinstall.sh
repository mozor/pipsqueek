#!/bin/bash

mkdir ~/pipsqueek
git clone https://github.com/mozor/pipsqueek.git ~/pipsqueek

cd ~/pipsqueek/
grep -RH ^use .|sed -e 's/.*:use //g' -e 's/;.*//g' -e 's/ .*//g'|sort|uniq > ~/pipsqueek/modules.txt

if [ -f /usr/bin/apt-get ]; then
        apt-get install --quiet curl;
        apt-get install --quiet cpan;
        curl -L http://cpanmin.us | perl - App::cpanminus
elif [ -f /usr/bin/yum ]; then
        yum install -y --quiet cpan.
        yum groupinstall -y --quiet "Development Tools";
        curl -L http://cpanmin.us | perl - App::cpanminus
else
        echo 'yo homie, I only support RHEL/CentOS and Debian/Ubuntu.'
        exit 0
fi

echo "Installing Perl Modules"

for package in $(cat ~/pipsqueek/modules.txt); 
do
        cpanm $package
done
