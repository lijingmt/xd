#include <command.h>
#include <globals.h> 
int main(string arg)
{
	string path,user_name,args,userip;//add by qianglee 0125
	string title = "";
	title += "=游客试玩=\n";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,args,userip)==4))
	{
		if(!user_name || !args || !userip)
		{
			title += "登陆过期\n";
			title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
			title += "[url 注册帐号:http://"+REG_URL+"]\n";
			write(title);
			return 1;
		}
		else if( sizeof(user_name)<2 || sizeof(args)<2 )
		{
			title += "登陆过期\n";
			title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
			title += "[url 注册帐号:http://"+REG_URL+"]\n";
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
				title += "登陆过期\n";
				title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
				title += "[url 注册帐号:http://"+REG_URL+"]\n";
				write(title);
				return 1;
			}
		}
		//找到用户档案，并取出该用户name，并对比
		string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		//没有此用户档案，是新用户，不允许在这里进行登录注册，直接返回
		if(!user)
		{
			object user_in_momery = find_player(user_name);
			//内存里有，也是正常登陆，可以登入游戏
			if(user_in_momery)
			{
				//这里进行用户自动注册过程
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
				//两个验证，sessionid和password
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
					title += "登陆过期\n";
					title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
					title += "[url 注册帐号:http://"+REG_URL+"]\n";
					write(title);
					return 1;
				}
			}
			else//内存里也没有这个帐号
			{
				//这里进行用户自动注册过程
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
		title += "登陆过期\n";
		title += "您的游客登陆已经过期，请返回首页注册帐号。\n";
		title += "[url 注册帐号:http://"+REG_URL+"]\n";
		write(title);
		return 1;
	}
	return 1;
}
