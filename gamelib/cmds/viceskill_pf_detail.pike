#include <command.h>
#include <gamelib/include/gamelib.h>
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/"
//arg = type p_id flag name
//   type="duanzao" , "liandan" "caifeng" or "zhijia"
//   flag = 0 只是查看配方
//   flag = 1 锻造时的显示
//   name 为锻造时加入的宝石名字
//锻造和炼丹公用这个指令来查看配方的具体信息，又加入了新的裁缝和制甲
private string add_enhancer(object me,string craft_type,string item_name)
{
	string expected_type = "moxian";
	array(object) inventory;
	object|zero found;
	if(craft_type=="duanzao")
		expected_type = "baoshi";
	if(!item_name || item_name=="none")
		return "";
	if(search(item_name,"/")!=-1 || search(item_name,"..")!=-1)
		return "强化材料参数无效。\n";
	if(!mappingp(me->baoshi_add))
		me->baoshi_add = ([]);
	if(me->baoshi_add[item_name])
		return "这种强化材料已经选择过了。\n";
	inventory = all_inventory(me);
	foreach(inventory,object item){
		if(item && functionp(item->is_combine_item) &&
		   item->is_combine_item() && item->query_name()==item_name &&
		   functionp(item->query_for_material) &&
		   (string)item->query_for_material()==expected_type){
			found = item;
			break;
		}
	}
	if(!found)
		return "你的包袱里没有这件可用的强化材料。\n";
	me->baoshi_add[item_name] = ({found->query_name_cn(),
		(int)found->query_add_luck()});
	return "已选择"+found->query_name_cn()+"；批量制作时每件都会消耗一份。\n";
}

int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	string type = "";
	int p_id = 0;
	int flag;
	string baoshi_name = "";
	sscanf(arg,"%s %d %d %s",type,p_id,flag,baoshi_name);
	ARTISAND->initialize_player(me);
	ARTISAND->refresh_material_cache(me);
	if(type == "duanzao"){
		string recipe_type = DUANZAOD->query_recipe_type(p_id);
		if(recipe_type=="")
			recipe_type = "m_weapon";
		s += DUANZAOD->query_pf_detail(me,p_id);
		if(flag == 1){
			s += add_enhancer(me,type,baoshi_name);
			if(sizeof(me->baoshi_add)>0){
				foreach(indices(me->baoshi_add),string baoshi_name){
					array tmp_arr = me->baoshi_add[baoshi_name];
					s += tmp_arr[0]+"x1\n";
				}
			}
			s += "[锻造1件:viceskill_duanzao_confirm "+p_id+" 1]";
			if(DUANZAOD->can_make_num(me,p_id)>=5)
				s += "|[锻造5件:viceskill_duanzao_confirm "+p_id+" 5]";
			if(DUANZAOD->can_make_num(me,p_id)>=10)
				s += "|[锻造10件:viceskill_duanzao_confirm "+p_id+" 10]";
			s += "\n";
			s += "[加入宝石:viceskill_add_baoshi "+p_id+"]\n";
			s += "\n[返回:viceskill_duanzao_list "+recipe_type+"]\n";
		}
		else if(flag == 0)
			s += "\n[返回:viceskill_duanzao_pf "+recipe_type+"]\n";
	}
	else if(type == "caifeng"){
		string recipe_type = CAIFENGD->query_recipe_type(p_id);
		if(recipe_type=="")
			recipe_type = "head";
		s += CAIFENGD->query_pf_detail(me,p_id);
		if(flag == 1){
			s += add_enhancer(me,type,baoshi_name);
			if(sizeof(me->baoshi_add)>0){
				foreach(indices(me->baoshi_add),string baoshi_name){
					array tmp_arr = me->baoshi_add[baoshi_name];
					s += tmp_arr[0]+"x1\n";
				}
			}
			s += "[缝制1件:viceskill_caifeng_confirm "+p_id+" 1]";
			if(CAIFENGD->can_make_num(me,p_id)>=5)
				s += "|[缝制5件:viceskill_caifeng_confirm "+p_id+" 5]";
			if(CAIFENGD->can_make_num(me,p_id)>=10)
				s += "|[缝制10件:viceskill_caifeng_confirm "+p_id+" 10]";
			s += "\n";
			s += "[加入魔线:viceskill_add_moxian_caifeng "+p_id+"]\n";
		}
		s += "\n[返回:viceskill_caifeng_pf "+recipe_type+"]\n";
	}
	if(type == "zhijia"){
		string recipe_type = ZHIJIAD->query_recipe_type(p_id);
		if(recipe_type=="")
			recipe_type = "head";
		s += ZHIJIAD->query_pf_detail(me,p_id);
		if(flag == 1){
			s += add_enhancer(me,type,baoshi_name);
			if(sizeof(me->baoshi_add)>0){
				foreach(indices(me->baoshi_add),string baoshi_name){
					array tmp_arr = me->baoshi_add[baoshi_name];
					s += tmp_arr[0]+"x1\n";
				}
			}
			s += "[制作1件:viceskill_zhijia_confirm "+p_id+" 1]";
			if(ZHIJIAD->can_make_num(me,p_id)>=5)
				s += "|[制作5件:viceskill_zhijia_confirm "+p_id+" 5]";
			if(ZHIJIAD->can_make_num(me,p_id)>=10)
				s += "|[制作10件:viceskill_zhijia_confirm "+p_id+" 10]";
			s += "\n";
			s += "[加入魔线:viceskill_add_moxian_zhijia "+p_id+"]\n";
		}
		s += "\n[返回:viceskill_zhijia_pf "+recipe_type+"]\n";
	}
	else if(type == "liandan"){
		string recipe_type = LIANDAND->query_recipe_type(p_id);
		if(recipe_type=="")
			recipe_type = "normal";
		s += LIANDAND->query_pf_detail(me,p_id);
		if(flag == 1){
		//	s += "[炼制:viceskill_liandan_confirm "+p_id+"]\n";
			s += "请输入炼制数量（1至100）：\n";
			s += "[int no:...]\n";
			s += "[submit 炼制:viceskill_liandan_confirm "+p_id+" ...]\n";

		}
		s += "\n[返回:viceskill_liandan_pf "+recipe_type+"]\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
