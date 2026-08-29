#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	s += "［人物状态］\n";
	s += "[［武器装备］:mytools]\n";
	s += "[［人物属性］:myinfo]\n";
	s += me->query_user_picture_url()+"\n";
	s += me->query_name_cn()+"\n";
	s += "ID:"+me->query_name()+(string)(me->game_fg||0)+"\n";
	s += "性别："+me->query_gender()+"\n";
	s += "称谓："+WAP_HONERD->query_honer_level_desc(me->honerlv,me->query_raceId())+"\n";
	s += "种族："+me->query_race_cn(me->query_raceId())+"\n";
	s += "职业："+me->query_profe_cn(me->query_profeId())+"\n";
	if(PROFESSIONVIPD->is_supported_profession(me->query_profeId())){
		mapping profession_status = PROFESSIONVIPD->query_status(me);
		s += "职业称号："+(string)profession_status["title"]+"\n";
		s += "职业外观："+(string)profession_status["style_name"]+"\n";
		s += "[职业助手:profession_assistant]\n";
	}
	s += "等级："+me->query_level()+" 级\n";
	s += VIPD->get_level_limit_des(me);
	s += VIPD->get_level_limit_action_links(me);
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
	s += "经验值："+format_game_number(me->current_exp)+"\n";
	s += "升级所需经验："+
		format_game_number(me->query_levelUp_need_exp())+"\n";
	s += "生命值："+format_game_number(me->get_cur_life())+"/"+
		format_game_number(me->query_life_max())+"\n";
	s += "法力值："+format_game_number(me->get_cur_mofa())+"/"+
		format_game_number(me->query_mofa_max())+"\n";
	s += "精力值："+format_game_number(me->query_jingli())+"\n";
	if(me->query_raceId()=="human")
		s += "仙气："+format_game_number(me->honerpt)+"("+
			format_game_number(me->killcount)+")\n";
	else if(me->query_raceId()=="monst")
		s += "妖气："+format_game_number(me->honerpt)+"("+
			format_game_number(me->killcount)+")\n";
	else if(me->query_raceId()=="third")
		s += "灵气："+format_game_number(me->honerpt)+"("+
			format_game_number(me->killcount)+")\n";
	s += "轮回值："+format_game_number(me->lunhuipt)+"\n";


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
	
	int donation_multiplier = me->query_donation_exp_multiplier();
	string bs_tips = "";
	if(donation_multiplier>1)
		bs_tips += "§6经验倍速开启："+
			(string)donation_multiplier+"倍§r";
	else
		bs_tips += "§6经验倍速尚未开启§r";
	bs_tips += "\n§6捐赠倍数作用于药品和活动加成后的打怪总经验§r\n";
	//if(bs_tips&&sizeof(bs_tips)) 
	
	bs_tips += "\n§6捐赠200元--2倍经验获得§r\n";
	bs_tips += "\n§6捐赠400元--3倍经验获得§r\n";
	bs_tips += "\n§6捐赠600元--4倍经验获得§r\n";	
	bs_tips += "\n§6捐赠获取更高经验倍数(最高50倍），QQ:1811117272§r\n";
	s += "\n"+bs_tips+"\n\n";
	
	s += "[返回游戏:look]\n";

	NEWBIED->record_action(me,"status");
	write(s);
	return 1;
}
