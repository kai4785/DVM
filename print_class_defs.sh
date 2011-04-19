#!/bin/bash

egrep --color "^ *class [a-Z_]+|this *\(.*\)$2" $1
