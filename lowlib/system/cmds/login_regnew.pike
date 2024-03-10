#include <globals.h> 
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string path,user_name,args,userip,game_fg,m_key,ip,ua;//add by qianglee 0125
	string title = "";
	//werror("\n\n======= arg = "+arg+"============\n\n");
    if(arg&&(sscanf(arg,"%s %s %s %s %s %s %s %s",path,user_name,args,userip,game_fg,m_key,ip,ua)==8)){
    //if(arg&&(sscanf(arg,"%s %s %s %s %s",path,user_name,args,userip,game_fg)==5)){
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
		//û�д��û������������û�����������������е�¼ע�ᣬֱ�ӷ���
		if(!user){
			//���������ʺ���������δ�����ڼ���ڴ���,������������ʺŵ�½
			object user_in_momery = find_player(user_name);
			if(user_in_momery){
				write("error1");
				return 1;
			}
			//��������û��Զ�ע�����
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
			if(!me)//�������û�������״̬,�������ɸ����������
			{
				me=u();
				me->set_name(user_name);
				me->set_project(path);
				me->set_userip(userip);
				if(me->setup(args)){
					exec(me,previous_object());
					if(environment(me)==0)
						me->move(LOW_VOID_OB);
					destruct(previous_object());
					//ע��ɹ�������
					string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+game_fg+"]["+ user_name +"]["+m_key+"]["+ip+"]["+ua+"]\n";
					//string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+game_fg+"]["+ user_name +"]["+m_key+"]\n";
					if(c_log != ""){
						Stdio.append_file(ROOT+"/log/stat/reg/"+GAME_NAME_S+"_reg_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
					}


					write(user_rtn+","+args);
					return 1;
				}
			}
			else//�������û��ղ����߲���project·����ȷ,�͵���reconnect
			{
				if(userip&&userip==me->query_userip()){
					if(me->query_project()==path&&me["reconnect"]&&me->reconnect(user_name)){
						exec(me,previous_object());
						destruct(previous_object());
					}
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
