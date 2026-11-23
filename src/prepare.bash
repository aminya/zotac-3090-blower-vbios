#!/usr/bin/bash

# download nvbios 
curl -LJ -o nvbios https://github.com/Panchovix/nvidia-vbios-vix-editor/releases/download/v0.1.46/nvbios-0.1.46-linux-x86_64
chmod +x ./nvbios

# download nvbios editor
curl -LJO https://github.com/Panchovix/nvidia-vbios-vix-editor/releases/download/v0.1.46/nvidia-vbios-vix-editor-0.1.46-linux-x86_64.tar.gz
tar -xzf nvidia-vbios-vix-editor-0.1.46-linux-x86_64.tar.gz
rm nvidia-vbios-vix-editor-0.1.46-linux-x86_64.tar.gz

