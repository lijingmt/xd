#include <globals.h>
#include <command.h>
int main(string arg)
{
	string path,user_name;
	werror("=======arg:"+arg+"\n");
	if(arg&&sscanf(arg,"%s %s",path,user_name)==2)
	{
	werror("=======path:"+path+"\n");
	werror("=======user_name:"+user_name+"\n");
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
		werror("=======login_fee_xd 111======\n");
		if(me->setup("none")){
		werror("=======login_fee_xd 222======\n");
			exec(me,previous_object());
			if(environment(me)==0)
				me->move(LOW_VOID_OB);
			destruct(previous_object());
		}
		else{ 
		werror("=======login_fee_xd 333======\n");
			if(me->query_project()==path&&me["reconnect"]&&me->reconnect("none")){
		werror("=======login_fee_xd 444======\n");
				exec(me,previous_object());
				destruct(previous_object());
			}
		}
		return 1;
	}
	return 1;
}
