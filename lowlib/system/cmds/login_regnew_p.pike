#include <globals.h> 
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string path,user_name,args,userip,game_fg;//add by qianglee 0125
	string title = "";
    	if(arg&&(sscanf(arg,"%s %s %s %s %s",path,user_name,args,userip,game_fg)==5)){
		if(!user_name || !args || !userip){
			write("error2");
			return 1;
		}
		else if( sizeof(user_name)<2 || sizeof(args)<2 ){
			write("error2");
			return 1;
		}
		for(int i=0;i<sizeof(user_name);i++){
			if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
				;
			else{
				write("error2");
				return 1;
			}
		}
		string user_rtn = user_name;
		user_name = game_fg+user_name;
		string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		if(!user){
			object user_in_momery = find_player(user_name);
			if(user_in_momery){
				write("error1");
				return 1;
			}
			program u;
			object m;
			catch{
				m=(object)(ROOT+"/"+path+"/master.pike");
			};
			if(m)
				u=m->connect();
			if(!u)
				u=(program)(ROOT+"/"+path+"/clone/user.pike");
			object me = find_player(user_name);
			if(!me)
			{
				me=u();
				me->set_name(user_name);
				me->set_project(path);
				//string ret = userip+random(1000000);
				//me->set_userencode(ret);	
				me->set_userip(userip);
				//if(me->setup(args,ret)){
				if(me->setup(args)){
					exec(me,previous_object());
					if(environment(me)==0)
						me->move(LOW_VOID_OB);
					destruct(previous_object());
					//write(ret+",null");
					write(user_rtn+","+args);
					return 1;
				}
			}
			else
			{
				//string ret = me->query_userencode();
				if(userip&&userip==me->query_userip()){
				//if(userip&&userip==ret){
					if(me->query_project()==path&&me["reconnect"]&&me->reconnect(user_name)){
						exec(me,previous_object());
						destruct(previous_object());
					}
					write(user_rtn+","+args);
					return 1;
					//write(ret+",null");
					//return 1;
				}
				else{
					write("error2");
					return 1;
				}
			}
			return 1;
		}
		else{
			write("error1");
			return 1;
		}
    }
    else{
	    write("error2");
	    return 1;
    }
    return 1;
}
