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
			//�ڴ����У�Ҳ��������½�����Ե�����Ϸ
			if(me){
				//������֤��sessionid��password
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
				//�ڴ���Ҳû������ʺ�,�������½
				write("error2");
				return 1;
			}
		}
		else{
			object me = find_player(user_name);
			//������û����û����ߣ�������֤
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
				//������û��������û������ߣ�������Ҫ�ҵ����û������е������ֶβ��Ա�lgpswd
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
