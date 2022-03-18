#!/bin/sh
stty -echo
printf "Enter secret input: "
read -r secret_input
printf "\n"
stty echo

printf "Enter visible input: "
read -r visible_input

# command to do later
printf "You entered:\n%s\n%s\n" "$secret_input" "$visible_input"
