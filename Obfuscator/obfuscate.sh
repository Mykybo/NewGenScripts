#!/bin/bash

obf="${1%.*}-obf.lua"
(cd XFuscator && lua XFuscator.lua ../$1 -noloadstring -nostep2 -uglify -fluff) &&
luajit -bs $obf $(basename $obf) &&
rm $obf
