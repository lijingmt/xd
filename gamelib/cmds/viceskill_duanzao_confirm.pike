#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = p_id 
//此指令完成锻造的最后阶段，即锻造出成品
int main(string arg)
{
	string s = "";
	object me=this_player();
	int p_id = (int)arg;
	//删除身上复数物品的接口为remove_combine_item(string name,int count),在gamelib/clone/user.pike中
	if(sizeof(me->material_m) == 0)
		s += "你不能进行这样的操作！\n";
	else if(DUANZAOD->can_make_num(me,p_id)==0){
		s += "你没有足够的材料！\n\n";
	}
	else if(me->if_over_easy_load()){
		s += "你随身物品已满，无法再存放更多的东西\n\n";
	}
	else{
		//先获得锻造物品的文件名
		string get_name = DUANZAOD->query_duanzao_item(p_id);
		//然后获得加入宝石的情况，计算出幸运值
		int luck = me->query_lunck(); 
		if(sizeof(me->baoshi_add) > 0){
			foreach(indices(me->baoshi_add),string baoshi){
				array tmp_arr2 = me->baoshi_add[baoshi];
				luck += tmp_arr2[1];
			}
		}
		object get_item = clone(ITEM_PATH+get_name);
		int item_level = DUANZAOD->query_item_level(p_id);
		if(get_item && get_item->query_item_from() == ""){
			//最后获得锻造的产物
			get_item = ITEMSD->dubo_item(item_level,get_name,luck);
		}
		if(get_item){
			//然后获得材料个数，从玩家身上删除所需要的材料
			mapping(string:array) tmp_m = DUANZAOD->query_get_m(p_id);
			foreach(indices(tmp_m),string material_name){
				array tmp_arr = tmp_m[material_name];
				me->remove_combine_item(material_name,tmp_arr[1]);
			}
			//删除宝石
			if(sizeof(me->baoshi_add) > 0){
				foreach(indices(me->baoshi_add),string baoshi){
					array tmp_arr2 = me->baoshi_add[baoshi];
					me->remove_combine_item(baoshi,1);
				}
			}
			string now=ctime(time());
			array(int) skill = me->vice_skills["duanzao"];
			s += "锻造成功!\n";
			string s_file = file_name(get_item);
			s += "你获得了["+get_item->query_name_cn()+":inv_other "+s_file+"]\n";
			//检查熟练度是否升级
			int now_lev = skill[0];
			if(now_lev<skill[2]){
				int update_need = (int)(now_lev/5);
				skill[1]++;
				if(skill[1]>=update_need){
					skill[0]++;
					skill[1]=0;
					s += "你的锻造熟练度提高到了"+(now_lev+1)+"级\n";
				}
			}
			me->baoshi_add = ([]);
			me->material_m = ([]);
			Stdio.append_file(ROOT+"/log/duanzao.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+")：锻造获得 "+get_item->query_name_cn()+"\n");
			get_item->move(me);	
		}
		else
			s += "锻造失败了\n";
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[继续锻造:viceskill_duanzao_list m_weapon]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
