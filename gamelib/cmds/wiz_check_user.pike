#include <command.h>
#include <gamelib/include/gamelib.h>
//查看玩家信息内容
int main(string arg)
{
	string s = "";
	object me = this_player();
	if(arg&&sizeof(arg)){
		object user = find_player(arg);
		if(!user){
			mixed err = catch{
				user = me->load_player(arg);
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
		string tmp="";
		s += "帐号："+user->query_name()+"\n";
		s += "-----------帐户信息-----------\n";
		s += "游戏名："+user->query_name_cn()+"\n";
		//s += "密码："+user->password+"\n";
		s += "职业："+user->query_profeId()+"\n";
		s += "等级："+user->query_level()+" [修改:wiz_modi_info level "+arg+" ...]\n";
		s += "金钱："+user->query_account()+" [修改:wiz_modi_info account "+arg+" ...]\n";
		s += "密码："+user->query_password()+" [修改:wiz_modi_info password "+arg+" ...]\n";
		s += "绑定手机："+user->query_mobile()+" [修改:wiz_modi_info mobile "+arg+" ...]\n";
		
		s +="-------------角色属性-------------\n";
		s += "攻击强度："+user->query_low_attack_desc()+"-"+user->query_high_attack_desc()+"\n";
		s += "防御强度："+user->query_defend_power()+"\n";

		s += "生命力："+user->get_cur_life()+"/"+user->query_life_max()+"\n";
		s += "法力值："+user->get_cur_mofa()+"/"+user->query_mofa_max()+"\n";
		s += "敏捷："+user->get_cur_dex();
		tmp = user->query_equip_add("dex")+user->query_equip_add("all");
		if(tmp)
			s += "＋"+tmp+"\n";
		else
			s += "\n";
		s += "力量："+user->get_cur_str();
		tmp = user->query_equip_add("str")+user->query_equip_add("all");
		if(tmp)
			s += "＋"+tmp+"\n";
		else
			s += "\n";
		s += "智力："+user->get_cur_think();
		tmp = user->query_equip_add("think")+user->query_equip_add("all");
		if(tmp)
			s += "＋"+tmp+"\n";
		else
			s += "\n";
		s += "闪避："+user->query_phy_dodge_str()+"%\n";
		s += "命中："+user->query_phy_hitte_str()+"%\n";
		s += "暴击："+user->query_phy_baoji_str()+"%\n";
	}
	s += "[返回:look]\n";
	s += "[返回游戏:qge74hye congxianzhen/xiaomuwu]\n";
	write(s);
	return 1;
}
