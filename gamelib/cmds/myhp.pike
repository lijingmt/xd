#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "［人物状态］\n";
	s += "[［武器装备］:mytools]\n";
	s += "[［人物属性］:myinfo]\n";
	s += me->query_user_picture_url()+"\n";
	s += me->query_name_cn()+"\n";
	s += "ID:"+me->query_name()-me->game_fg+"\n";
	s += "性别："+me->query_gender()+"\n";
	s += "称谓："+WAP_HONERD->query_honer_level_desc(me->honerlv,me->query_raceId())+"\n";
	s += "种族："+me->query_race_cn(me->query_raceId())+"\n";
	s += "职业："+me->query_profe_cn(me->query_profeId())+"\n";
	s += "等级："+me->query_level()+" 级\n";
	s += "嗑药："+me->query_danyao_effect()+"\n";
	s += "特效："+me->query_teyao_effect()+"\n";
	s += "家园特效："+me->query_homeBuff_effect()+"\n";
	string rst = "";
	if(me->bangid)
		rst += BANGD->query_bang_name(me->bangid);
	if(rst&&sizeof(rst)){
		rst = "帮派：<"+rst+">*"+BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		s += rst;
	}
	s += "经验值："+me->current_exp+"\n";
	s += "升级所需经验："+me->query_levelUp_need_exp()+"\n";
	s += "生命值："+me->get_cur_life()+"/"+me->query_life_max()+"\n";
	s += "法力值："+me->get_cur_mofa()+"/"+me->query_mofa_max()+"\n";
	s += "精力值："+me->query_jingli()+"\n"; 
	if(me->query_raceId()=="human")
		s += "仙气："+me->honerpt+"("+me->killcount+")\n";
	else if(me->query_raceId()=="monst")
		s += "妖气："+me->honerpt+"("+me->killcount+")\n";
	s += "轮回值："+me->lunhuipt+"\n";


/*
	int game_hour = me->query_user_hour();
	int game_mint = me->query_user_mint();

	s += "剩余游戏时间：\n";
	if(game_hour&&game_mint){
		s += game_hour+" 小时 ";
		s += game_mint+" 分钟\n ";
	}
	else if(game_hour)
		s += game_hour+" 小时\n";
	else if(game_mint)
		s += game_mint+" 分钟\n ";
	//else
	//	s += "您的游戏时间已经用完，请冲值获得游戏时间。\n";
*/
	
	int szx=0;
	string bs_tips = "";
	if(me->all_fee>=200){
		szx = me->all_fee;
		if(szx>=200 && szx<400){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：2倍</font>";	
		}
		if(szx>=400 && szx<600){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：3倍</font>";	
		}
		if(szx>=600 && szx<800){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：4倍</font>";	
		}
		if(szx>=800 && szx<1000){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：5倍</font>";	
		}
		if(szx>=1000 && szx<1200){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：6倍</font>";	
		}
		if(szx>=1200 && szx<1400){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：8倍</font>";	
		}
		if(szx>=1400 && szx<1600){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：10倍</font>";	
		}
		if(szx>=1600 && szx<3200){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：20倍</font>";	
		}
		if(szx>=3200 && szx<6400){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：30倍</font>";	
		}
		if(szx>=6400 && szx<12800){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：40倍</font>";	
		}
		if(szx>=12800 && szx<25600){
			bs_tips += "<font style=\"color:DARKORANGE\">经验倍速开启：50倍</font>";	
		}
	}
 	else
		bs_tips += "<font style=\"color:DARKORANGE\">经验倍速尚未开启</font>";	
	//if(bs_tips&&sizeof(bs_tips)) 
	
	bs_tips += "\n<font style=\"color:DARKORANGE\">捐赠200元--2倍经验获得</font>\n";
	bs_tips += "\n<font style=\"color:DARKORANGE\">捐赠400元--3倍经验获得</font>\n";
	bs_tips += "\n<font style=\"color:DARKORANGE\">捐赠600元--4倍经验获得</font>\n";	
	bs_tips += "\n<font style=\"color:DARKORANGE\">捐赠获取更高经验倍数(最高50倍），QQ:1811117272</font>\n";
	s += "\n"+bs_tips+"\n\n";
	
	s += "[返回游戏:look]\n";
	
	write(s);
	return 1;
}
