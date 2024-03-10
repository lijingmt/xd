#include <command.h>
#include <globals.h>
int main(string arg)
{
	string path,user_name,args,userip;
	string title = "";
	title += "=游客试玩=\n";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,args,userip)==4))
	{
		//检查用户名，密码的有效性
		if(!user_name || !args || !userip)
		{
			title += "登陆过期\n";
			title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
			title += "[url 注册帐号:http://"+REG_URL+"]\n";
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
			if(!me)//如果这个用户不再线状态,重新生成个人物体对象
			{
				title += "您对我们的游戏还满意吗？\n";
				title += "如果您觉得好玩，请注册游戏，正式开始仙道旅程吧。\n";
				//title += "登陆过期\n";
				//title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
				title += "[url 注册帐号:http://"+REG_URL+"]\n";
				write(title);
				return 1;
			}
			else//如果这个用户刚才再线并且project路径正确,就调用reconnect
			{
				string pswd = me->password;
				string userSID = me->query_userip();
				//如果不是同一个手机登陆，jsessionid不同，就踢出去
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
					title += "登陆过期\n";
					title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
					title += "[url 注册帐号:http://"+REG_URL+"]\n";
					write(title);
					return 1;
				}
			}
			return 1;
	}
	else
	{
		title += "登陆过期\n";
		title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
		title += "[url 注册帐号:http://"+REG_URL+"]\n";
		write(title);
		return 1;
	}
	return 1;
}
