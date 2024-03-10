#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令列出55级幻境中可用混沌碎片合成的【混沌】饰品和血火石换取的【狐】武器名称
//arg = type
//type = "hundun" "hu"
int main(string arg){
	string s = "";
	object me = this_player();
	string type = arg;
	if(type == "hundun"){
		s += "【混沌】饰品\n";
		s += "\n";
		s += "[【混沌】噩梦:huanjin_equip_exchange "+type+" 55emeng 30 0]\n";
		s += "[【混沌】守护:huanjin_equip_exchange "+type+" 55shouhu 30 0]\n";
		s += "[【混沌】冥晦:huanjin_equip_exchange "+type+" 55minghui 30 0]\n";
	}
	else if(type == "hu"){
		s += "【狐】武器\n";
		s += "\n";
		s += "[【狐】紫阳剑:huanjin_equip_exchange "+type+" 55ziyangjian 40 0]\n";
		s += "[【狐】天荒宝刀:huanjin_equip_exchange "+type+" 55tianhuangbaodao 80 0]\n";
		s += "[【狐】摄天匕:huanjin_equip_exchange "+type+" 55shetianbi 40 0]\n";
		s += "[【狐】流霜月魄杖:huanjin_equip_exchange "+type+" 55liushuangyuehunzhang 80 0]\n";
		s += "[【狐】寒月流光:huanjin_equip_exchange "+type+" 55hanyueliuguang 35 0]\n";
		s += "[【狐】丰都御魂:huanjin_equip_exchange "+type+" 55fengduyuhun 35 0]\n";
		s += "[【狐】承影匕首:huanjin_equip_exchange "+type+" 55chengyingbishou 35 0]\n";
		s += "[【狐】纯均匕首:huanjin_equip_exchange "+type+" 55chunjunbishou 35 0]\n";
		s += "[【狐】天丛云剑:huanjin_equip_exchange "+type+" 55tiancongyunjian 70 0]\n";
		s += "[【狐】青龙戟:huanjin_equip_exchange "+type+" 55qinglongji 70 0]\n";
		s += "[【狐】冰心火雨:huanjin_equip_exchange "+type+" 55bingxinhuoyu 70 0]\n";
		s += "[【狐】月之冕:huanjin_equip_exchange "+type+" 55yuezhimian 70 0]\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
