#!/bin/sh
PASSWORD=$1

make clean
sshpass -p $PASSWORD make package install