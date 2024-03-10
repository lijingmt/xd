//! 连接管理Daemon
#include "lowlib.h"
mapping(object:object) conn_map;
mapping(object:int) users;
object this_player;
void create()
{
	conn_map=([]);
	users=([]);
}
void set_conn(object user,object conn)
{
	conn_map[user]=conn;
	users[user]=1;
}
void erase_conn(object user)
{
	users[conn_map[user]]=0;
	m_delete(conn_map,user);
}
object query_conn(object user)
{
	return conn_map[user];
}
void set_this_player(object user)
{
	this_player=user;
}
object query_this_player()
{
	return this_player;
}
array(object) query_users(void|int all)
{
	if(all){
		return indices(users)-({0});
	}
	else{
		return indices(filter(users,`!=,0))-({0});
	}
}
