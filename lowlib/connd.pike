//! 杩炴帴绠＄悊Daemon
#include "lowlib.h"
mapping(object:object) conn_map;
mapping(object:int) users;
private Thread.Local thread_this_player = Thread.Local();
private Thread.Mutex connection_lock = Thread.Mutex();
protected void create()
{
	conn_map=set_weak_flag(([]),Pike.WEAK_INDICES);
	users=set_weak_flag(([]),Pike.WEAK_INDICES);
}
void set_conn(object user,object conn)
{
	object key=connection_lock->lock();
	conn_map[user]=conn;
	users[user]=1;
	destruct(key);
}
void erase_conn(object user)
{
	object key=connection_lock->lock();
	m_delete(users,user);
	m_delete(conn_map,user);
	destruct(key);
}
void erase_user(object user)
{
	object key=connection_lock->lock();
	users[user]=0;
	m_delete(users,user);
	m_delete(conn_map,user);
	destruct(key);
}
object query_conn(object user)
{
	object key=connection_lock->lock();
	object conn=conn_map[user];
	destruct(key);
	return conn;
}
void set_this_player(object user)
{
	thread_this_player->set(user);
}
object query_this_player()
{
	return thread_this_player->get();
}
array(object) query_users(void|int all)
{
	array(object) result;
	object key=connection_lock->lock();
	if(all){
		result=indices(users)-({0});
	}
	else{
		result=indices(filter(users,`!=,0))-({0});
	}
	destruct(key);
	return result;
}
