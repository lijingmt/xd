#!/bin/bash
#!/usr/local/bin/pike
/bin/kill $(ps ax|grep pike|grep 5499|cut -d' ' -f1)
/bin/kill $(ps ax|grep pike|grep 5499|cut -d' ' -f2)
/bin/kill $(ps ax|grep pike|grep 5499|cut -d' ' -f3)

/usr/local/games/xiand9/lowlib/driver.pike -i 127.0.0.1 -p 5499 /usr/local/games/xiand9/ &
