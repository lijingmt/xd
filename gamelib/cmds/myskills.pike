#include <command.h>
#include <gamelib/include/gamelib.h>
#define limitpost 900
int main(string|zero arg)
{
	string s = "";
	ARTISAND->initialize_player(this_player());
	NEWBIED->record_action(this_player(),"skills");
	if(this_player()->home_path&&this_player()->home_path!="")
		s += "[传送回家:home_return "+this_player()->home_path+"]\n";
	s += this_player()->view_skills();
	if(this_player()->query_profeId()=="fangshi"){
		s += "[召唤灵兽:summon]\n";
		s += "[方士专属·灵契共鸣:summon list]\n";
		s += "[灵契助手（技能手动使用永久免费）:profession_assistant]\n";
	}
	if(this_player()->query_profeId()=="zhenyue"){
		if(this_player()->query_buff("team_guard",0)=="absorb")
			s += "【山河壁】剩余"+
				this_player()->query_buff("team_guard",1)+"点，约"+
				this_player()->query_buff("team_guard",2)+"秒。\n";
		s += "[镇越守御路线:newbie_guide roadmap]|[队伍:my_term]\n";
		s += "[山河守御助手（技能手动使用永久免费）:profession_assistant]\n";
	}
	if(this_player()->query_profeId()=="tianxiang"){
		int marks = this_player()->query_tianxiang_star_marks();
		s += "【星痕】"+marks+"/3（每次生成刷新15秒；换房、脱战、死亡或离线清空）\n";
		s += "[天象星痕路线:newbie_guide roadmap]\n";
		s += "[观星助手（技能手动使用永久免费）:profession_assistant]\n";
	}
	if(this_player()->query_profeId()=="lingyi"){
		int pacts = this_player()->query_lingyi_medicine_pacts();
		mapping(string:int) revive =
			this_player()->query_lingyi_auto_revive_status();
		s += "【药契】"+pacts+"/3（有效治疗刷新20秒；换房、脱战、死亡或离线清空）\n";
		if(revive["unlocked"])
			s += "【百炼复苏】已掌握"+revive["mastered"]+
				"门满段技能，今日"+revive["remaining"]+"/"+
				revive["maximum"]+"次（自动触发，恢复25%生命/20%仙力）\n";
		else
			s += "【百炼复苏】满段技能"+revive["mastered"]+
				"/5（五段即100%掌握，达标后每日自动复苏1次）\n";
		s += "[灵医济世路线:newbie_guide roadmap]|[队伍:my_term]\n";
		s += "[百草助手（技能手动使用永久免费）:profession_assistant]\n";
	}
	if(this_player()->query_profeId()=="wuxiang"){
		// 无相心法：展示当前最高项；无相化身：120 级后显示今日剩余次数
		int s_v = this_player()->get_cur_str();
		int d_v = this_player()->get_cur_dex();
		int t_v = this_player()->get_cur_think();
		string highest = s_v>=d_v && s_v>=t_v ? "力量" :
			(d_v>=s_v && d_v>=t_v ? "敏捷" : "智力");
		s += "【无相心法】当前最高项："+highest+
			"（结算时其 50% 加成另外两系；不入存档、不参与装备门槛）\n";
		if(this_player()->query_level() >= 120){
			int used = this_player()->query_wuxiang_avatar_used();
			s += "【无相化身】今日剩余 "+(1-used)+
				"/1 次（致命伤自动恢复 25% 生命；自杀/切磋/城战不触发）\n";
		}
		else
			s += "【无相化身】120 级解锁：每日一次免疫致命伤\n";
		s += "[无相补位路线:newbie_guide roadmap]|[队伍:my_term]\n";
	}
	//增加特殊技能链接
	//由liaocheng于07/5/8修改
	if(this_player()->can_spec == 1){
		if(this_player()->query_profeId() == "jianxian"){
			int now = time();
			if(now >= this_player()["/spec_skill/coldtime"])
				s += "[【仙】御剑术:spec_yujianshu 1]\n";
			else{
				int time_remain = this_player()["/spec_skill/coldtime"] - now;
				int min = (int)time_remain/60;
				if(time_remain%60 > 0)
					min++;
				s +="[【仙】御剑术:spec_yujianshu 0](还有"+min+"分钟冷却)\n";
			}
		}
		else if(this_player()->query_profeId() == "yinggui"){
			if(this_player()->hind == 1)
				s += "[【影】显形:spec_xianxing]\n";
			else{
				int now = time();
				if(now>=this_player()["/spec_skill/coldtime"])
					s += "[【影】影遁:spec_yingdun 1](隐藏身形，耗法300，冷却时间15分钟)\n";
				else{
					int time_remain = this_player()["/spec_skill/coldtime"] - now;
					int min = (int)time_remain/60;
					if(time_remain%60 > 0)
						min++;
					s +="[【影】影遁:spec_yingdun 0](还有"+min+"分钟冷却)\n";
				}
			}
		}
		else if(this_player()->query_profeId() == "yushi" || this_player()->query_profeId() == "wuyao"){
			int now = time();
			//coldtime 记录化物术冷却时间
			//coldtime2 记录凝液术冷却时间
			if(now>=this_player()["/spec_skill/coldtime"])
				s += "[【术】化物术:spec_huawu 1]\n";
			else{
				int time_remain = this_player()["/spec_skill/coldtime"] - now;
				int min = (int)time_remain/60;
				if(time_remain%60 > 0)
					min++;
				s +="[【术】化物术:spec_huawu 0](还有"+min+"分钟冷却)\n";
			}
			if(now>=this_player()["/spec_skill/coldtime2"])
				s += "[【术】凝液术:spec_ningye 1]\n";
			else{
				int time_remain = this_player()["/spec_skill/coldtime2"] - now;
				int min = (int)time_remain/60;
				if(time_remain%60 > 0)
					min++;
				s += "[【术】凝液术:spec_ningye 0](还有"+min+"分钟冷却)\n";
			}
		}
	}

	int time_limit = time() - (int)this_player()["/post/posttime"];
	//得到传送地点名称///////////////////
	string postpath = "";
	object tob;
	mixed err=catch{
		tob = (object)(ROOT+this_player()->relife);
	};
	if(!err)
		postpath += tob->query_name_cn(); 
	//得到传送地点名称///////////////////
	if(time_limit>=limitpost)
		s += "[传送回"+postpath+":postcity "+this_player()->relife+"]\n";
	else{
		int mint = (limitpost-time_limit)/60;
		if(mint==0)
			mint = 1;
		s += "你还需要 "+mint+" 分钟才能使用传送功能回到 "+postpath+"。\n";
	}
	//if(this_player()->vice_skills==0)
	//	this_player()->vice_skills = ([]);
	s += "辅助技能：[百工坊:artisan]\n";
	if(sizeof(this_player()->vice_skills) > 0){
		array(int) vice_tmp = ({});
		if(this_player()->vice_skills["caikuang"]){
			vice_tmp = this_player()->vice_skills["caikuang"];
			s += "[采矿:viceskill_view caikuang]("+vice_tmp[0]+"/"+vice_tmp[2]+")\n";
		}
		if(this_player()->vice_skills["duanzao"]){
			vice_tmp = this_player()->vice_skills["duanzao"];
			s += "[锻造:viceskill_view duanzao]("+vice_tmp[0]+"/"+vice_tmp[2]+")\n";
		}
		if(this_player()->vice_skills["caiyao"]){
			vice_tmp = this_player()->vice_skills["caiyao"];
			s += "[采药:viceskill_view caiyao]("+vice_tmp[0]+"/"+vice_tmp[2]+")\n";
		}
		if(this_player()->vice_skills["liandan"]){
			vice_tmp = this_player()->vice_skills["liandan"];
			s += "[炼丹:viceskill_view liandan]("+vice_tmp[0]+"/"+vice_tmp[2]+")\n";
		}
		if(this_player()->vice_skills["caifeng"]){
			vice_tmp = this_player()->vice_skills["caifeng"];
			s += "[裁缝:viceskill_view caifeng]("+vice_tmp[0]+"/"+vice_tmp[2]+")\n";
		}
		if(this_player()->vice_skills["zhijia"]){
			vice_tmp = this_player()->vice_skills["zhijia"];
			s += "[制甲:viceskill_view zhijia]("+vice_tmp[0]+"/"+vice_tmp[2]+")\n";
		}
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
