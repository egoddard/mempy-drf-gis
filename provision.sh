#!/bin/bash

if [ -f /etc/apt/sources.list.d/ubuntugis-ubuntugis-unstable-trusty.list ]
then
    echo "UbuntuGIS ppa already added."
else
    sudo add-apt-repository -y -s ppa:ubuntugis/ubuntugis-unstable
fi

sudo apt-get update
sudo apt-get -y upgrade

sudo apt-get -y install postgresql postgresql-client postgresql-contrib \
    postgresql-server-dev-all postgis gdal-bin libgdal20 python-pip python3-pip 

if [ ! -d $HOME/.virtualenvs ]
then
    mkdir $HOME/.virtualenvs
fi

sudo pip install virtualenvwrapper

echo "export WORKON_HOME=$HOME/.virtualenvs" >> ~/.bashrc
#echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.bashrc
sudo ln -s /usr/local/bin/virtualenvwrapper.sh /etc/profile.d/virtualenvwrapper.sh

sudo sed -i 's/local   all             postgres                                peer/local   all             all                                     trust/' /etc/postgresql/9.3/main/pg_hba.conf
sudo service postgresql reload
