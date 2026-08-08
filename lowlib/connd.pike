//! 杩炴帴绠＄悊Daemon
#include "lowlib.h"
mapping(object:object) conn_map;
mapping(object:int) users;
private Thread.Local thread_this_player = Thread.Local();
private Thread.Mutex connection_lock = Thread.Mutex();
private mapping(string:array(int)) registration_rates = ([]);
private int last_registration_cleanup;
private mapping(string:array(int)) authentication_rates = ([]);
private int last_authentication_cleanup;
#define MAX_REGISTRATION_RATE_KEYS 4096
#define MAX_AUTHENTICATION_RATE_KEYS 4096
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

int registration_attempt_allowed(string ip)
{
	int now = time();
	int allowed = 1;
	object key = connection_lock->lock();
	if(!ip || ip=="" || sizeof(ip)>64)
		ip = "unknown";
	else{
		for(int n=0;n<sizeof(ip);n++){
			int ch = ip[n];
			if(!((ch>='0' && ch<='9') || (ch>='a' && ch<='f') ||
			   (ch>='A' && ch<='F') || ch=='.' || ch==':' ||
			   ch=='[' || ch==']')){
				ip = "unknown";
				break;
			}
		}
	}
	if(now-last_registration_cleanup>=60){
		foreach(indices(registration_rates),string old_ip){
			array(int) old_rate = registration_rates[old_ip];
			if(!old_rate || sizeof(old_rate)<2 || now-old_rate[0]>=60)
				m_delete(registration_rates,old_ip);
		}
		last_registration_cleanup = now;
	}
	array(int) rate = registration_rates[ip];
	if(rate && now-rate[0]>=60){
		rate = ({now,0});
		registration_rates[ip] = rate;
	}
	if(!rate && sizeof(registration_rates)>=MAX_REGISTRATION_RATE_KEYS){
		ip = "overflow";
		rate = registration_rates[ip];
	}
	if(rate && now-rate[0]>=60){
		rate = ({now,0});
		registration_rates[ip] = rate;
	}
	if(!rate){
		rate = ({now,0});
		registration_rates[ip] = rate;
	}
	if(rate[1]>=5)
		allowed = 0;
	else
		rate[1]++;
	destruct(key);
	return allowed;
}

int authentication_attempt_allowed(string ip)
{
	int now = time();
	int allowed = 1;
	object key = connection_lock->lock();
	if(!ip || ip=="" || sizeof(ip)>64)
		ip = "unknown";
	else{
		for(int n=0;n<sizeof(ip);n++){
			int ch = ip[n];
			if(!((ch>='0' && ch<='9') || (ch>='a' && ch<='f') ||
			   (ch>='A' && ch<='F') || ch=='.' || ch==':' ||
			   ch=='[' || ch==']')){
				ip = "unknown";
				break;
			}
		}
	}
	if(now-last_authentication_cleanup>=60){
		foreach(indices(authentication_rates),string old_ip){
			array(int) old_rate = authentication_rates[old_ip];
			if(!old_rate || sizeof(old_rate)<2 || now-old_rate[0]>=60)
				m_delete(authentication_rates,old_ip);
		}
		last_authentication_cleanup = now;
	}
	array(int) rate = authentication_rates[ip];
	if(rate && now-rate[0]>=60){
		rate = ({now,0});
		authentication_rates[ip] = rate;
	}
	if(!rate && sizeof(authentication_rates)>=MAX_AUTHENTICATION_RATE_KEYS){
		ip = "overflow";
		rate = authentication_rates[ip];
	}
	if(rate && now-rate[0]>=60){
		rate = ({now,0});
		authentication_rates[ip] = rate;
	}
	if(!rate){
		rate = ({now,0});
		authentication_rates[ip] = rate;
	}
	if(rate[1]>=10)
		allowed = 0;
	else
		rate[1]++;
	destruct(key);
	return allowed;
}
