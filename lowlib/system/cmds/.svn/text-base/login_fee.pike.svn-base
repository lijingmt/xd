#include <globals.h>
#include <command.h>
int main(string arg)
{
	string path,user_name,args;
	if(arg&&sscanf(arg,"%s %s",path,user_name)==2)
	{
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
		if(!me){
			string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
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
			me=u();
			me->set_name(user_name);
			me->set_project(path);
			if(me->setup(pswd)){
				exec(me,previous_object());
				if(environment(me)==0)
					me->move(LOW_VOID_OB);
				destruct(previous_object());
			}
			else{
				if(me->query_project()==path&&me["reconnect"]&&me->reconnect(me->password)){
					exec(me,previous_object());
					destruct(previous_object());
				}
			}
			return 1;
		}
		else{ 
			if(me->query_project()==path&&me["reconnect"]&&me->reconnect(me->password)){
				exec(me,previous_object());
				destruct(previous_object());
			}
			return 1;
		}
	}
}
