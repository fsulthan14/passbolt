#!/bin/bash

dirName=$(dirname "$0")
echo "[INFO] Install Scripts.."
mkdir -p ~/bin
cp -R ${dirName}/bin/* ~/bin

