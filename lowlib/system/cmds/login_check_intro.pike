#include <command.h>
#include <globals.h> 
int main(string arg)
{
	string path,user_name,args,userip;//add by qianglee 0125
	string title = "";
	title += "=�ο�����=\n";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,args,userip)==4))
	{
		if(!user_name || !args || !userip)
		{
			title += "��½����\n";
			title += "�����ο͵�½�Ѿ����ڣ��뷵����ҳע���ʺš�\n";
			title += "[url ע���ʺ�:http://"+REG_URL+"]\n";
			write(title);
			return 1;
		}
		else if( sizeof(user_name)<2 || sizeof(args)<2 )
		{
			title += "��½����\n";
			title += "�����ο͵�½�Ѿ����ڣ��뷵����ҳע���ʺš�\n";
			title += "[url ע���ʺ�:http://"+REG_URL+"]\n";
			write(title);
			return 1;
		}
		for(int i=0;i<sizeof(user_name);i++)
		{
			if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
			{

			}
			else
			{
				title += "��½����\n";
				title += "�����ο͵�½�Ѿ����ڣ��뷵����ҳע���ʺš�\n";
				title += "[url ע���ʺ�:http://"+REG_URL+"]\n";
				write(title);
				return 1;
			}
		}
		//�ҵ��û���������ȡ�����û�name�����Ա�
		string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		//û�д��û������������û�����������������е�¼ע�ᣬֱ�ӷ���
		if(!user)
		{
			object user_in_momery = find_player(user_name);
			//�ڴ����У�Ҳ��������½�����Ե�����Ϸ
			if(user_in_momery)
			{
				//��������û��Զ�ע�����
				program u;
				object m;
				catch
				{
					m=(object)(ROOT+"/"+path+"/master.pike");
				};
				if(m)
				{
					u=m->connect();
				}
				if(!u)
				{
					u=(program)(ROOT+"/"+path+"/clone/user.pike");
				}
				object me = find_player(user_name);
				//������֤��sessionid��password
				if( userip&&userip==me->query_userip() && args&&args==me->password )
				{
					if(me->query_project()==path&&me["reconnect"]&&me->reconnect(user_name))
					{
						exec(me,previous_object());
						destruct(previous_object());
					}
				}
				else
				{
					title += "��½����\n";
					title += "�����ο͵�½�Ѿ����ڣ��뷵����ҳע���ʺš�\n";
					title += "[url ע���ʺ�:http://"+REG_URL+"]\n";
					write(title);
					return 1;
				}
			}
			else//�ڴ���Ҳû������ʺ�
			{
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
				if(!me){
					me=u();
					me->set_name(user_name);
					me->set_project(path);
					me->set_userip(userip);
					object old_this_player=this_player();
					if(me->setup(user_name)){
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
	else
	{
		title += "��½����\n";
		title += "�����ο͵�½�Ѿ����ڣ��뷵����ҳע���ʺš�\n";
		title += "[url ע���ʺ�:http://"+REG_URL+"]\n";
		write(title);
		return 1;
	}
	return 1;
}
