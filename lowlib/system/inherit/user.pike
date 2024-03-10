#include <globals.h>
inherit LOW_BASE;
inherit LOW_F_CMDS;

int online_time;
int first_login;
int login_time;
private int update_time;
private int reconnect_time;
private int reconnect_count;

/****   添加的代码     ****/      
//通过链接的频率来滤出外挂的玩家，由liaocheng于2008-10-24添加
private int reconnect_delay;//这次连接与上次连接的时间差
private int illegal_count;//若这次时间差与上次时间差一样，则视为一次非法记录，非法记录超过某一值了则视为外挂
private int bad_rcd;//非法记录的次数，超过一个值了则视为外挂，送小黑屋     //新增

void check_reconnect_delay()
{
	if(reconnect_time){
		string now=ctime(time());
		string s_mon,s_day;
		int day,mon,year;
		mapping now_time = localtime(time());
		string s_log = "";
		string time_tail = "";
		int this_delay = time()-reconnect_time;
		if(this_delay == reconnect_delay && reconnect_delay <= 2)
			illegal_count++;
		else
			illegal_count = 0;
		if(illegal_count >= 20){
		//if(illegal_count >= 2){//测试用
			//外挂的处理在这里添加
			//目前是记录非法用户，不做其他任何操作
			//踢入到输入验证码的房间
			//this_object()->command("qge74hye check_room");    //需要输入验证的房间
			bad_rcd++;
			s_log = ""+now[0..sizeof(now)-2]+"|user:"+this_object()->query_name()+"|time_delay:"+reconnect_delay+"s|bad_rcd:"+bad_rcd+"\n"; 
			day = now_time["mday"];	
			mon = now_time["mon"]+1;
			year = now_time["year"]+1900;
			if(mon<10)
				s_mon = "0"+mon;
			else
				s_mon = (string)mon;
			if(day<10)
				s_day = "0"+day;
			else
				s_day = (string)day;
			time_tail = ""+year+"-"+s_mon+"-"+s_day;
			Stdio.append_file(ROOT+"/log/waigua/waigua_check_"+time_tail+".log",s_log); //写入log文件

			illegal_count = 0;
		}
		    if(bad_rcd >0 &&bad_rcd%10== 0){
		    //if(bad_rcd >0 &&bad_rcd%2== 0){//测试用
			//非法记录超过规定次数，送小黑屋
			this_object()->command("qge74hye check_room");    //需要输入验证的房间
			//this_object()->command("qge74hye xinshou/xiaoheiwu");   //小黑屋
			//Stdio.append_file(ROOT+"/txonline/etc/reserved_mobile",this_object()->query_name()+"\n");
			//由于玩家对象正在被访问，所以不能让玩家对象当即存档下线，这里设置一个定时器，让系统踢下线
			//call_out(waigua_remove,2);
			s_log = ""+now[0..sizeof(now)-2]+"|user:"+this_object()->query_name()+"|time_delay:"+reconnect_delay+"s|bad_rcd:"+bad_rcd+"|caught\n"; 
			bad_rcd++;
			day = now_time["mday"];	
			mon = now_time["mon"]+1;
			year = now_time["year"]+1900;
			if(mon<10)
				s_mon = "0"+mon;
			else
				s_mon = (string)mon;
			if(day<10)
				s_day = "0"+day;
			else
				s_day = (string)day;
			time_tail = ""+year+"-"+s_mon+"-"+s_day;
			Stdio.append_file(ROOT+"/log/waigua/waigua_in_heiwu_"+time_tail+".log",s_log); //写入log文件

		}

		reconnect_delay = this_delay;
	}
	return;
}
int update_online_time(){
	online_time+=time()-update_time;
	update_time=time();
	return online_time;
}
int query_idle(){
	return time()-reconnect_time;
}
int query_online(){
	return time()-update_time;
}
int query_reconnect_count(){
	return reconnect_count;
}
#ifdef __INTERACTIVE_CATCH_TELL__
void catch_tell(string str) {
    receive(str);
}
#endif
string query_cwd(){
	return "";
}
void write_prompt() {}
array(string) query_command_prefix(){
	return ({COMMAND_PREFIX});
}
string process_input(string arg){
    if(arg=="flush_filter"){
	    flush_filter();
	    return 0;
    }
    return arg;
}
void init(){
	//werror("\n     system/clone/user.pike->init called\n");
	if (this_object() == this_player()) {
		//werror("\n      call add_action\n");
		add_action("command_hook", "", 1);
	}
}
void create()
{
}
void receive_message(string newclass, string msg){
	receive(msg);
}
int setup(string arg){
	first_login=login_time=update_time=reconnect_time=time();
    set_heart_beat(1);
    set_living_name(name);
    enable_commands();
    //add for password by calvin 2006-12-08
    set_password(arg);
	//add for password by calvin 2006-12-08
	set_this_player(this_object());
    return 1;
}
#ifndef __NO_ENVIRONMENT__
void tell_room(object ob, string msg){
    foreach (all_inventory(ob) - ({ this_object() }),ob)
        tell_object(ob, msg);
}
#endif
void net_dead(){
	call_out(remove,3);
}
int reconnect(string arg){
	if(arg&&arg==password){
		//check_reconnect_delay(); //在这里添加检查频率的方法
		reconnect_time=time();
		reconnect_count++;
		remove_call_out(remove);
		return 1;
	}
	else
		return 0;
}
private string project;
void set_project(string arg){
	project=arg;
}
string query_project(){
	return project;
}
