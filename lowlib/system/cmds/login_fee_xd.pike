#include <globals.h>
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string path,user_name,maintenance_token;
	string expected_token = getenv("XIAND_MAINTENANCE_TOKEN") || "";
	if(arg&&sscanf(arg,"%s %s %s",path,user_name,maintenance_token)==3)
	{
		if(sizeof(expected_token)<24 || maintenance_token!=expected_token){
			write("维护登录认证失败。\n");
			return 1;
		}
		if(!LOGICALZONED->login_allowed(user_name)){
			write("该逻辑区尚未开放或正在维护。\n");
			return 1;
		}
		//[login_fee gamenv fhwl111]
		//werror("=======path:"+path+"\n");
		program u;
		object m;
		catch{
			m=(object)(ROOT+"/"+path+"/master.pike");
		};
		if(m)
			u=m->connect();
		if(!u)
			u=(program)(ROOT+"/"+path+"/clone/user.pike");
		////////////////////////////////////////////////////
		object me=u();
		me->set_name(user_name);
		me->set_project(path);
		if(me->setup("none")){
			exec(me,previous_object());
			if(environment(me)==0)
				me->move(LOW_VOID_OB);
			destruct(previous_object());
		}
		else{ 
			if(me->query_project()==path&&me["reconnect"]&&me->reconnect("none")){
				exec(me,previous_object());
				destruct(previous_object());
			}
		}
		return 1;
	}
	write("维护登录认证失败。\n");
	return 1;
}
