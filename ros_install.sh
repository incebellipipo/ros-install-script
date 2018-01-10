#!/bin/bash
# The BSD License
# Copyright (c) 2014 OROCA and ROS Korea Users Group

set -x

function usage {
    # Print out usage of this script.
    echo >&2 "usage: $0 [catkin workspace name (default:catkin_ws)] [ROS distro (default: indigo)"
    echo >&2 "          [-h|--help] Print help message."
    exit 0
}

function get-shell {
    current_user=`id -u -n`
    shell=`cat /etc/passwd | grep $current_user | cut -d ':' -f 7`
    echo ${shell##*/}
}

# Parse command line. If the number of argument differs from what is expected, call `usage` function.
OPT=`getopt -o h -l help -- $*`
if [ $# != 2 ]; then
    usage
fi
eval set -- $OPT
while [ -n "$1" ] ; do
    case $1 in
        -h|--help) usage ;;
        --) shift; break;;
        *) echo "Unknown option($1)"; usage;;
    esac
done

name_catkinws=$1
name_catkinws=${name_catkinws:="catkin_ws"}
name_ros_distro=$2
name_ros_distro=${name_ros_distro:="xenial"}
username=`id -u -n`
version=`cat /etc/*-release | grep UBUNTU_CODENAME | awk -F '=' '{print $2}'`

echo "[Checking the ubuntu version]"
case $version in
  "saucy" | "trusty" | "vivid" | "wily" | "xenial")
  ;;
  *)
    echo "ERROR: This script will only work on Ubuntu Saucy(13.10) / Trusty(14.04) / Vivid / Wily / Xenial. Exit."
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
relesenum=`grep DISTRIB_DESCRIPTION /etc/*-release | awk -F 'Ubuntu ' '{print $2}' | awk -F ' LTS' '{print $1}'`
if [ "$relesenum" = "14.04.2" ]
then
  echo "Your ubuntu version is $relesenum"
  echo "Intstall the libgl1-mesa-dev-lts-utopic package to solve the dependency issues for the ROS installation specifically on $relesenum"
  sudo apt-get install -y libgl1-mesa-dev-lts-utopic
else
  echo "Your ubuntu version is $relesenum"
fi

echo "[Installing chrony and setting the ntpdate]"
sudo apt-get install -y chrony
sudo ntpdate ntp.ubuntu.com

echo "[Add the ROS repository]"
if [ ! -e /etc/apt/sources.list.d/ros-latest.list ]; then
  sudo sh -c "echo \"deb http://packages.ros.org/ros/ubuntu ${version} main\" > /etc/apt/sources.list.d/ros-latest.list"
fi

echo "[Download the ROS keys]"
roskey=`apt-key list | grep "ROS builder"`
if [ -z "$roskey" ]; then
  wget --quiet https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -O - | sudo apt-key add -
fi

echo "[Update & upgrade the package]"
sudo apt-get update
sudo apt-get upgrade

echo "[Installing ROS]"
sudo apt-get install -y ros-'$name_ros_distro'-desktop-full ros-'$name_ros_distro'-rqt-*

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
user_shell=`get-shell`
sh -c "echo \"source /opt/ros/$name_ros_distro/setup.$user_shell\" >> ~/."$user_shell"rc"
sh -c "echo \"source ~/$name_catkinws/devel/setup.bash\" >> ~/."$user_shell"rc"
sh -c "echo \"export ROS_MASTER_URI=http://localhost:11311\" >> ~/."$user_shell"rc"
sh -c "echo \"export ROS_HOSTNAME=localhost\" >> ~/."$user_shell"rc"

echo "[Complete!!!]"

exec bash

exit 0

