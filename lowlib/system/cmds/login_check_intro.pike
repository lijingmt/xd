#include <command.h>
#include <globals.h> 
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string path,user_name,args,userip;//add by qianglee 0125
	string title = "";
	title += "=娓稿璇曠帺=\n";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,args,userip)==4))
	{
		if(path!="gamelib"){
			write("登录过期\n");
			return 1;
		}
		if(!user_name || !args || !userip)
		{
			title += "登录过期\n";
			title += "鎮ㄧ殑娓稿鐧婚檰宸茬粡杩囨湡锛岃杩斿洖棣栭〉注册账号銆俓n";
			title += "[url 注册账号:http://"+REG_URL+"]\n";
			write(title);
			return 1;
		}
		else if( sizeof(user_name)<2 || sizeof(args)<2 )
		{
			title += "登录过期\n";
			title += "鎮ㄧ殑娓稿鐧婚檰宸茬粡杩囨湡锛岃杩斿洖棣栭〉注册账号銆俓n";
			title += "[url 注册账号:http://"+REG_URL+"]\n";
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
				title += "登录过期\n";
				title += "鎮ㄧ殑娓稿鐧婚檰宸茬粡杩囨湡锛岃杩斿洖棣栭〉注册账号銆俓n";
				title += "[url 注册账号:http://"+REG_URL+"]\n";
				write(title);
				return 1;
			}
		}
		if(!LOGICALZONED->login_allowed(user_name)){
			title += "该逻辑区尚未开放或正在维护。\n";
			write(title);
			return 1;
		}
		//鎵惧埌鐢ㄦ埛妗ｆ锛屽苟鍙栧嚭璇ョ敤鎴穘ame锛屽苟瀵规瘮
		string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		//娌℃湁姝ょ敤鎴锋。妗堬紝鏄柊鐢ㄦ埛锛屼笉鍏佽鍦ㄨ繖閲岃繘琛岀櫥褰曟敞鍐岋紝鐩存帴杩斿洖
		if(!user)
		{
			object user_in_momery = find_player(user_name);
			//鍐呭瓨閲屾湁锛屼篃鏄甯哥櫥闄嗭紝鍙互鐧诲叆娓告垙
			if(user_in_momery)
			{
				//杩欓噷杩涜鐢ㄦ埛鑷姩娉ㄥ唽杩囩▼
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
					title += "登录过期\n";
					title += "鎮ㄧ殑娓稿鐧婚檰宸茬粡杩囨湡锛岃杩斿洖棣栭〉注册账号銆俓n";
					title += "[url 注册账号:http://"+REG_URL+"]\n";
					write(title);
					return 1;
				}
			}
			else//内存里也没有这个账号
			{
				//杩欓噷杩涜鐢ㄦ埛鑷姩娉ㄥ唽杩囩▼
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
		title += "登录过期\n";
		title += "鎮ㄧ殑娓稿鐧婚檰宸茬粡杩囨湡锛岃杩斿洖棣栭〉注册账号銆俓n";
		title += "[url 注册账号:http://"+REG_URL+"]\n";
		write(title);
		return 1;
	}
	return 1;
}
