#!/bin/bash
#!/usr/local/bin/pike
cp vendue_confirm.pike bandpsw_change_confirm.pike msg_write_confirm.pike present_set.pike ../gamelib/cmds/
cp -rf armor decorate jewelry weapon ../gamelib/clone/item/
cp -rf log db_log callback_add.pike startup.sh ../
cp -rf etc ../gamelib/
cp globals.h ../lowlib/system/include/
cp hosts_list ../lowlib/etc/
cp -rf udtestII ../../


