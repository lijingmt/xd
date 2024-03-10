#include <command.h>
#include <gamelib/include/gamelib.h>
//修改玩家信息
int main(string arg)
{
	string s = "";
	object me = this_player();
	string per_name = "";//需要修改的属性
	string uid  = "";//需要修改的玩家id
	string new_per = "";//新的属性值
	string m_log = "";//修改记录
	string now = ctime(time());
	if(arg){
		sscanf(arg,"%s %s %s",per_name,uid,new_per);

		werror("----arg = "+arg+"-----\n");
		object user = find_player(uid);
		if(!user){
			mixed err = catch{
				user = me->load_player(uid);
			};
			
			if(err){
				s += "load player wrong\n";
				s += "[返回:look]\n";
				s += "[返回游戏:qge74hye congxianzhen/xiaomuwu]\n";
				write(s);
				return 1;
			}
			if(!user){
				s += "无此玩家，请确认输入正确\n";
				s += "[返回:look]\n";
				s += "[返回游戏:qge74hye congxianzhen/xiaomuwu]\n";
				write(s);
				return 1;
			}
		}
		if(user){
			if(me->query_name() == user->query_name()){
				s += "不能自己修改自己的帐号信息\n";
				s += "[返回:look]\n";
				s += "[返回游戏:qge74hye congxianzhen/xiaomuwu]\n";
				write(s);
				return 1;
			}
			m_log = user->query_name_cn()+ "("+user->query_name()+")的 "+ per_name + " 从 ";
			if("level"==per_name)
			{
				m_log += user->query_level();
				user->level = (int)new_per;
				m_log += " 修改为 "+ user->query_level();
			}
			else if("account"==per_name)
			{
				m_log += user->query_account();
				user->set_account((int)new_per);
				m_log += " 修改为 "+ user->query_account();
			}
			else if("password"==per_name)
			{
				m_log += user->query_password();
				user->set_password(new_per);
				m_log += " 修改为 "+ user->query_password();
			}
			else if("mobile"==per_name)
			{
				m_log += user->query_mobile();
				user->set_mobile(new_per);
				m_log += " 修改为 "+ user->query_mobile();
			}
		
			Stdio.append_file(ROOT+"/log/user_modi.log",now[0..sizeof(now)-2]+":"+m_log+"\n");
			user->remove();
			me->command("wiz_check_user "+uid);
			return 1;
		}
		else{
			s += "无此玩家，请确认输入正确\n";
			s += "[返回:look]\n";
			s += "[返回游戏:qge74hye congxianzhen/xiaomuwu]\n";
			write(s);
			return 1;
		}

	}
}
