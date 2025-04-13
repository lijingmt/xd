#!/bin/bash
#!/usr/local/bin/pike8
/bin/kill $(ps ax|grep pike|grep 13800|cut -d' ' -f1)
/bin/kill $(ps ax|grep pike|grep 13800|cut -d' ' -f2)
/bin/kill $(ps ax|grep pike|grep 13800|cut -d' ' -f3)

pike8 /usr/local/games/xiand/lowlib/driver.pike -i 127.0.0.1 -p 13800 /usr/local/games/xiand/ &
