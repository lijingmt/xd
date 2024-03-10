#include <command.h>
#include <gamelib/include/gamelib.h>
#define limitpost 900
int main(string arg)
{
	string s = "";
	if(this_player()->home_path&&this_player()->home_path!="")
		s += "[传送回家:home_return "+this_player()->home_path+"]\n";
	s += this_player()->view_skills();
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
	if(sizeof(this_player()->vice_skills) > 0){
		s += "辅助技能：\n";
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

