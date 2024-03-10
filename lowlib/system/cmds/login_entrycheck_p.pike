#include <globals.h>
int main(string arg)
{
	string path,user_name,lgpswd,userip;
	string title = "";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,lgpswd,userip)==4)){
		string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		if(!user){
			object me = find_player(user_name);
			if(me){
				//string pswd = me->password;
				//string ret = me->query_userencode();
				//if(pswd && lgpswd==pswd){
				if(userip&&userip==me->userip&&me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
				//	if(me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
						exec(me,previous_object());
						destruct(previous_object());
						write(ret+",null");
						return 1;
					}
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
		}
		else{
			object me = find_player(user_name);
			if(me){
				string pswd = me->password;
				if(pswd && lgpswd==pswd){
					string ret = userip+random(1000000);
    					set_living_info_name(user_name+"|"+pswd,ret);
					me->set_userencode(ret);
					if(me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
						exec(me,previous_object());
						destruct(previous_object());
					}
					write(ret+",null");
					return 1;
				}
				else{
					write("error3");
					return 1;
				}
			}
			else{
				string pswd;
				array(string) usr_content=user/"\n";
				foreach(usr_content,string strCompare){
					if((strCompare/" ")[0]=="password"){
						if( (strCompare/" ")[1] ){
							string pswdTmp = (strCompare/" ")[1];
							pswd =(pswdTmp/"\"")[1];
						}
					}
				}
				if(pswd && lgpswd!=pswd){
					write("error3");
					return 1;
				}
				if(pswd && lgpswd==pswd){
					program u;
					object m;
					catch{
						m=(object)(ROOT+"/"+path+"/master.pike");
					};
					if(m){
						u=m->connect();
					}
					if(!u){
						u=(program)(ROOT+"/"+path+"/clone/user.pike");
					}
					me=u();
					me->set_name(user_name);
					me->set_userip("not_use");
					me->set_project(path);
					string ret = userip+random(1000000);
					me->set_userencode(ret);
					if(me->setup(lgpswd,ret)){
						exec(me,previous_object());
						if(environment(me)==0){
							me->move(LOW_VOID_OB);
						}
						destruct(previous_object());
						write(ret+",null");
						return 1;
					}
				}
			}
		}
	}
	else{
		write("error4");
		return 1;
	}
	return 1;
}
