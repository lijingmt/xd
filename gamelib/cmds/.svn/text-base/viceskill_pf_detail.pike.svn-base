#include <command.h>
#include <gamelib/include/gamelib.h>
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/"
//arg = type p_id flag name
//   type="duanzao" , "liandan" "caifeng" or "zhijia"
//   flag = 0 只是查看配方
//   flag = 1 锻造时的显示
//   name 为锻造时加入的宝石名字
//锻造和炼丹公用这个指令来查看配方的具体信息，又加入了新的裁缝和制甲
int main(string arg)
{
	string s = "";
	object me=this_player();
	string type = "";
	int p_id = 0;
	int flag;
	string baoshi_name = "";
	sscanf(arg,"%s %d %d %s",type,p_id,flag,baoshi_name);
	if(type == "duanzao"){
		s += DUANZAOD->query_pf_detail(me,p_id);
		if(flag == 1){
			if(baoshi_name != "none"){
				object ob = clone(MATERIAL_PATH+baoshi_name);
				if(ob){
					int add_luck = ob->query_add_luck();
					string name_cn = ob->query_name_cn();
					me->baoshi_add[baoshi_name] += ({name_cn,add_luck});
				}
			}
			if(sizeof(me->baoshi_add)>0){
				foreach(indices(me->baoshi_add),string baoshi_name){
					array tmp_arr = me->baoshi_add[baoshi_name];
					s += tmp_arr[0]+"x1\n";
				}
			}
			s += "[锻造:viceskill_duanzao_confirm "+p_id+"]\n";
			s += "[加入宝石:viceskill_add_baoshi "+p_id+"]\n";
			s += "\n[返回:viceskill_duanzao_list m_weapon]\n";
		}
		else if(flag == 0)
			s += "\n[返回:viceskill_duanzao_pf m_weapon]\n";
	}
	else if(type == "caifeng"){
		s += CAIFENGD->query_pf_detail(me,p_id);
		if(flag == 1){
			if(baoshi_name != "none"){
				object ob = clone(MATERIAL_PATH+baoshi_name);
				if(ob){
					int add_luck = ob->query_add_luck();
					string name_cn = ob->query_name_cn();
					me->baoshi_add[baoshi_name] += ({name_cn,add_luck});
				}
			}
			if(sizeof(me->baoshi_add)>0){
				foreach(indices(me->baoshi_add),string baoshi_name){
					array tmp_arr = me->baoshi_add[baoshi_name];
					s += tmp_arr[0]+"x1\n";
				}
			}
			s += "[缝制:viceskill_caifeng_confirm "+p_id+"]\n";
			s += "[加入魔线:viceskill_add_moxian_caifeng "+p_id+"]\n";
		}
		s += "\n[返回:viceskill_caifeng_pf head]\n";
	}
	if(type == "zhijia"){
		s += ZHIJIAD->query_pf_detail(me,p_id);
		if(flag == 1){
			if(baoshi_name != "none"){
				object ob = clone(MATERIAL_PATH+baoshi_name);
				if(ob){
					int add_luck = ob->query_add_luck();
					string name_cn = ob->query_name_cn();
					me->baoshi_add[baoshi_name] += ({name_cn,add_luck});
				}
			}
			if(sizeof(me->baoshi_add)>0){
				foreach(indices(me->baoshi_add),string baoshi_name){
					array tmp_arr = me->baoshi_add[baoshi_name];
					s += tmp_arr[0]+"x1\n";
				}
			}
			s += "[制作:viceskill_zhijia_confirm "+p_id+"]\n";
			s += "[加入魔线:viceskill_add_moxian_zhijia "+p_id+"]\n";
		}
		s += "\n[返回:viceskill_zhijia_pf head]\n";
	}
	else if(type == "liandan"){
		s += LIANDAND->query_pf_detail(me,p_id);
		if(flag == 1){
		//	s += "[炼制:viceskill_liandan_confirm "+p_id+"]\n";
			s += "请输入炼制数量：\n";                                                                           
			s += "[int no:...]\n";
			s += "[submit 炼制:viceskill_liandan_confirm "+p_id+" ...]\n";

		}
		s += "\n[返回:viceskill_liandan_pf normal]\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
