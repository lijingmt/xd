#include <command.h>
#include <globals.h>
int main(string arg)
{
	string path,user_name,args,userip;
	string title = "";
	title += "=�ο�����=\n";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,args,userip)==4))
	{
		//����û������������Ч��
		if(!user_name || !args || !userip)
		{
			title += "��½����\n";
			title += "�����ο͵�½�Ѿ����ڣ��뷵����ҳע���ʺš�\n";
			title += "[url ע���ʺ�:http://"+REG_URL+"]\n";
			write(title);
			return 1;
		}
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
			if(!me)//�������û�������״̬,�������ɸ����������
			{
				title += "�������ǵ���Ϸ��������\n";
				title += "��������ú��棬��ע����Ϸ����ʽ��ʼ�ɵ��ó̰ɡ�\n";
				//title += "��½����\n";
				//title += "�����ο͵�½�Ѿ����ڣ��뷵����ҳע���ʺš�\n";
				title += "[url ע���ʺ�:http://"+REG_URL+"]\n";
				write(title);
				return 1;
			}
			else//�������û��ղ����߲���project·����ȷ,�͵���reconnect
			{
				string pswd = me->password;
				string userSID = me->query_userip();
				//�������ͬһ���ֻ���½��jsessionid��ͬ�����߳�ȥ
				if( (pswd && args==pswd) && (userSID && userip==userSID) )
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
			return 1;
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
