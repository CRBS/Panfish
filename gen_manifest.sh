#!/bin/bash

# This script


echo "Changes" > MANIFEST
echo "Makefile.PL" >> MANIFEST
echo "MANIFEST" >> MANIFEST
echo "README" >> MANIFEST
echo "lib/Panfish.pm" >> MANIFEST

find lib/ -name "*.pm" -type f >> MANIFEST

find t/ -name "*.t" -type f >> MANIFEST

find t/ -name "*.pm" -type f >> MANIFEST

find bin/ -name "*" -type f >> MANIFEST

