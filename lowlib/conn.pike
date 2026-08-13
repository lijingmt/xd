//! 用户连接类
#define __NO_WRITE_OVERRIDE__
#include "lowlib.h"
#include <gamelib/include/time.h>
#include <globals.h>
Stdio.File conn;
object user;
string in;
string out;
int closing;
function on_input;
mixed on_input_args;
object filter;
object query_filter()
{
	return filter;//EFUNSD->player_filter[user];
}

string query_remote_ip()
{
	if(!conn)
		return "";
	string address = conn->query_address();
	if(!address || address=="")
		return "";
	array(string) parts = String.trim_all_whites(address)/" ";
	if(!sizeof(parts))
		return "";
	string ip = parts[0];
	if(sizeof(ip)>=2 && ip[0]=='['){
		int bracket = search(ip,"]");
		if(bracket>1)
			ip = ip[1..bracket-1];
	}
	else{
		string host = "";
		int port = 0;
		if(sscanf(ip,"%s:%d",host,port)==2 && search(host,":")==-1)
			ip = host;
	}
	return ip;
}
//该write方法其实调用filter进行转换，如果设置了filter的时候
int write(string s)
{
	object old=EFUNSD->this_player();
	EFUNSD->set_this_player(user);
	object filter=query_filter();
	if(filter)
		s=filter->filter(s);
	out+=s;
	if(sizeof(out))//不管是否通过filter层转换，如果有数据，下面就可以调用读写回调方法处理之
		conn->set_nonblocking(read_callback,write_callback,close_callback);
	EFUNSD->set_this_player(old);
	if(!user){
		close();
	}
	return s?sizeof(s):1;
}
protected void tryclose()
{
	//werror("========tryclose call==========\n");
	if(closing&&in==""&&out==""){
		if(user){
			//werror("---- tryclose clean this user call CONND->erase_conn(user) ----\n");
			CONND->erase_conn(user);
			//如果游戏实体对象user存在net_dead方法，调用将会在wapmud2层被inherit/user.pike截取，调用
			//call_out(remove,living_time);
			if(user["net_dead"])
				user->net_dead();
		}
		//werror("----tryclose conn->close()----\n");
		conn->set_nonblocking();
		conn->close();
		destruct(this_object());
	}
	//werror("========tryclose end==========\n");
}
protected void write_callback(mixed id)
{
	int n=conn->write(out);
	out=out[n..];
	if(sizeof(out)==0){
		conn->set_nonblocking(read_callback,0,close_callback);
	}
	tryclose();
}
protected void read_callback(mixed id,string data)
{
	if(!user){
		conn->close();
		return;
	}
	in+=data;
	array(string) l=in/"\n";
	if(sizeof(l)>0)
		in=l[sizeof(l)-1];
	for(int i=0;i<sizeof(l)-1;i++){
		CONND->set_this_player(user);
		string s=l[i];
		if(sizeof(s)>0&&s[sizeof(s)-1]=='\r')
			s=s[0..sizeof(s)-2];
		mixed err;
		if(on_input){
			function f=on_input;
			mixed args=on_input_args;
			on_input=0;
			on_input_args=0;
			f(user,s,@args);
		}
		else{
			err=catch{
				object filter=query_filter();
				if(filter&&filter["process_input"])
					s=filter->process_input(s);
				if(user){
					if(user["process_input"]){
						string t=user->process_input(s);
						s=t;
					}
					if(s){
						if(s=="0")
							s = "look what";
						EFUNSD->command(s,user);
						/*
						object obt= System.Time();
						int st =  obt->usec_full;
						EFUNSD->command(s,user);
						if(user){
							int timediff = (obt->usec_full - st)/1000;
							array at1 = (s/" ");
							if(at1&&sizeof(at1)){
								if(at1[0]=="login"||at1[0]=="set_filter"||at1[0]=="look"||at1[0]=="login_des"||at1[0]=="login_des_p"||at1[0]=="flushview")
									;
								else
									Stdio.append_file(ROOT+"/log/cmd_record.log."+get_time(),"["+user->name+"]["+s+"] ["+timediff+"]\n");
							}
							else
								Stdio.append_file(ROOT+"/log/cmd_record.log."+get_time(),"["+user->name+"]["+s+"] ["+timediff+"]\n");
						}
						*/
					}
				}
			};
		}
		if(this_object()&&!on_input){
			if(user&&user["write_prompt"]){
				user->write_prompt();
			}
			else{
				//write("> ");
			}
		}
		if(err!=0){
			master()->handle_error(err);
		}
	}
	//werror("========read_callback end==========\n");
}
void close()
{
	if(closing){
		tryclose();
		return;
	}
	closing=1;
	object filter=query_filter();
	if(filter){
		object ob=filter;
		if(ob["net_dead"]){
			string s=ob->net_dead();
			out+=s;
		}
	}
	// Don't call tryclose yet - let write_callback handle it after data is sent
	if(sizeof(out)){
		conn->set_nonblocking(0,write_callback,close_callback);
	}
	else{
		tryclose();
	}
}
protected void close_callback(mixed id)
{
	//werror("========close_callback call==========\n");
	close();
	//werror("========close_callback end==========\n");
}
protected void create(Stdio.File c,object ob)
{
	in="";
	out="";
	on_input=0;
	conn=c;
	conn->set_nonblocking(read_callback,write_callback,close_callback);
	user=ob;
	CONND->set_conn(ob,this_object());
	CONND->set_this_player(user);
	ob->logon();
}
void set_user(object dest)
{
	//werror("========set_user call==========\n");
	user=dest;
	//werror("========set_user end==========\n");
}
void input_to(string|function fun, void|int is_passwd1_noskip2, mixed ... args)//XXX:is_passwd1_noskip2 not supported
{
	//werror("========input_to call==========\n");
	if(on_input==0){
		on_input=fun;
		on_input_args=args;
	}
	//werror("========input_to end==========\n");
}
