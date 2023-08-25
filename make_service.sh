#!/usr/bin/bash

echo "Copying accord-chat.service -> /etc/systemd/system/"

sed -e "s|/path/to/accord-chat|$(pwd -P)|g" accord-chat.service | tee /etc/systemd/system/accord-chat.service

id "accord-chat" &> /dev/null || echo -e  "\e[33mWarning, user 'accord-chat' does not exist\e[0m" >&2

echo  -e "\e[32mNow run 'sudo systemctl daemon-reload && sudo systemctl start accord-chat'\e[0m"
 