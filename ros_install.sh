#!/bin/bash
# The BSD License
# Copyright (c) 2014 OROCA and ROS Korea Users Group

function usage {
    # Print out usage of this script.
    echo >&2 "usage: $0 [catkin workspace name (default:catkin_ws)] [ROS distro (default: kinetic)"
    echo >&2 "          [-h|--help]    Print help message."
    echo >&2 "          [-v|--verbose] Verbose output."
    exit 0
}

function get-shell {
    current_user=`id -u -n`
    shell=`cat /etc/passwd | grep $current_user | cut -d ':' -f 7`
    echo ${shell##*/}
}

# Parse command line. If the number of argument differs from what is expected, call `usage` function.
OPTS=`getopt -o vhns: --long help,verbose: -n 'parse-options' -- "$@"`
if [ $# != 2 ]; then
    usage
fi
eval set -- $OPT
while [ -n "$1" ] ; do
    case $1 in
        -h | --help) 
          usage
          shift; 
          ;;
        -v | --verbose)
          set -x
          shift;
          ;;
        --) 
          shift; 
          break
          ;;
        *) 
          echo "Unknown option($1)"; 
          usage
          ;;
    esac
done

name_catkinws=$1
name_catkinws=${name_catkinws:="ros_ws"}
name_ros_distro=$2
name_ros_distro=${name_ros_distro:="kinetic"}

username=`id -u -n`

user_shell=`get-shell`

if [ -d /etc/upstream-release ] ; then
    relesenum=`cat /etc/upstream-release/lsb-release | grep DESCRIPTION | awk -F 'Ubuntu ' '{print $2}' | awk -F ' LTS' '{print $1}'`
    ubuntu_version=`cat /etc/upstream-release/lsb-release | grep CODENAME | awk -F '=' '{print $2}'`
else
    relesenum=`cat /etc/lsb-release | grep DESCRIPTION | awk -F 'Ubuntu ' '{print $2}' | awk -F ' LTS' '{print $1}'`
    ubuntu_version=`cat /etc/lsb-release | grep CODENAME | awk -F '=' '{print $2}'`
fi

its_okay_to_install=false

read -p "Which package do you want to install? 1. Full Desktop, 2. Desktop, 3. Bare Bones? " answer
case "$answer" in
  "1")
    package_type="desktop-full"
    ;;
  "2")
    package_type="desktop"
    ;;
  "3")
    package_type="ros-base"
    ;;
  * )
    package_type="ros-base"
    ;;
esac

install_rqt=""
read -p "Do you also install all rqt packages? (Y/n) " answer
case ${answer} in
  n|N)
    ;;
  *)
    install_rqt="ros-${name_ros_distro}-rqt-*"
    ;;
esac

# check if ubuntu version and ros version is meet correctly
case $name_ros_distro in
  "lunar" )
    if [[ "$ubuntu_version" == +(xenial|yakkety|zesty)  ]] ; then
      its_okay_to_install=true
    fi
    ;;
  "kinetic" )
    if [[ "$ubuntu_version" == +(wily|xenial) ]] ; then
      its_okay_to_install=true
    fi
    ;;
  "jade" )
    if [[ "$ubuntu_version" == +(trusty|utopic|vivid) ]] ; then
      its_okay_to_install=true
    fi
    ;;
  "igloo" )
    if [[ "$ubuntu_version" == +(saucy|trusty) ]] ; then
      its_okay_to_install=true
    fi
    ;;
esac

if ! $its_okay_to_install ; then
    echo "Selected ros version and current ubuntu version is not met."
    echo "Please refer to page: http://www.ros.org/reps/rep-0003.html"
    exit 1
fi

echo "[Checking the ubuntu version]"
case $ubuntu_version in
  "saucy" | "trusty" | "vivid" | "wily" | "xenial" | "yakkety" | "zesty" )
  ;;
  *) echo "ERROR: This script will only work on Ubuntu Saucy(13.10) / Trusty(14.04) / Vivid / Wily / Xenial / Yakkety / Zesty and their forks. Exit."
    exit 0
esac

if ! [ -x "$(command -v sudo)" ]
then
  apt update
  apt install sudo
fi

echo "[Update & upgrade the package]"
sudo apt-get update
sudo apt-get upgrade -y 

echo "[Check the 14.04.2 TLS issue]"
if [ "$relesenum" = "14.04.2" ]
then
  echo "Your ubuntu version is $relesenum"
  echo "Intstall the libgl1-mesa-dev-lts-utopic package to solve the dependency issues for the ROS installation specifically on $relesenum"
  sudo apt-get install -y libgl1-mesa-dev-lts-utopic
else
  echo "Your ubuntu version is $relesenum"
fi

echo "[Installing chrony and setting the ntpdate]"
  sudo apt-get install -y chrony ntpdate
sudo ntpdate ntp.ubuntu.com

echo "[Add the ROS repository]"
if [ ! -e /etc/apt/sources.list.d/ros-latest.list ]; then
  sudo sh -c "echo \"deb http://packages.ros.org/ros/ubuntu ${ubuntu_version} main\" > /etc/apt/sources.list.d/ros-latest.list"
fi

echo "[Download the ROS keys]"
roskey=`apt-key list | grep "ROS builder"`
if [ -z "$roskey" ]; then
  wget --quiet https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -O - | sudo apt-key add -
fi

echo "[Update & upgrade the package]"

sudo apt-get update
sudo apt-get upgrade -y

echo "[Installing ROS]"


sudo apt-get install -y ros-${name_ros_distro}-${package_type} ${install_rqt}

if ! [ $? -eq 0 ] ; then
  echo "Failure detected when installing ros packages, exiting"
  exit 1
fi

echo "[rosdep init and python-rosinstall]"
sudo sh -c "rosdep init"
rosdep update
. /opt/ros/$name_ros_distro/setup.sh
sudo apt-get install -y python-rosinstall

echo "[Making the catkin workspace and testing the catkin_make]"
mkdir -p ~/$name_catkinws/src
cd ~/$name_catkinws/src
catkin_init_workspace
cd ~/$name_catkinws/
catkin_make

echo "[Setting the ROS evironment]"
echo "source ~/${name_catkinws}/devel/setup.${user_shell}" | tee -a ~/.${user_shell}rc

echo "[Complete!!!]"

exit 0
