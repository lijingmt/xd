#include <globals.h>

// write by zpc 20070706

int main(string arg)
{
	string path,user_name,lgpswd,userip;
	string title = "";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,lgpswd,userip)==4)){
		string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		if(!user){
			object me = find_player(user_name);
			//内存里有，也是正常登陆，可以登入游戏
			if(me){
				//两个验证，sessionid和password
				if(userip&&userip==me->userip&&me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
					exec(me,previous_object());
					destruct(previous_object());
				}
				else{
					write("error1");
					return 1;
				}
			}
			else{
				//内存里也没有这个帐号,不允许登陆
				write("error2");
				return 1;
			}
		}
		else{
			object me = find_player(user_name);
			//有这个用户，用户在线，进行验证
			if(me){
				if(me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
					exec(me,previous_object());
					destruct(previous_object());
				}
				else{
					write("error3");
					return 1;
				}
			}
			else{
				//有这个用户，但是用户不在线，这里需要找到该用户档案中的密码字段并对比lgpswd
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
					me->set_userip(userip);
					me->set_project(path);
					if(me->setup(lgpswd)){
						exec(me,previous_object());
						if(environment(me)==0){
							me->move(LOW_VOID_OB);
						}
						destruct(previous_object());
					}
					return 1;
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
