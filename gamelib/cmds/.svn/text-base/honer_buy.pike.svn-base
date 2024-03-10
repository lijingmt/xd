#include <command.h>
#include <gamelib/include/gamelib.h>
#define HONER ROOT "/gamelib/clone/item/honer/"
//arg = type name flag
// type为"duanzao" or "liandan" ;name为配方文件; flag为0表示察看，为1表示购买
int main(string arg)
{
	string s = "荣誉属于真正的勇者\n";
	object me=this_player();
	string filename = "";
	string need_name = "";//兑换需要物品的名词
	int need_num = 0;//兑换需要物品的数量
	string type = "";
	int flag = 0;
	string producer_info = "";
	sscanf(arg,"%s %s %s %d %d",type,filename,need_name,need_num,flag);
	object ob;
	ob = clone(HONER+filename);
	object need_ob = clone(ITEM_PATH+"bossdrop/"+need_name);
	if(ob){
		int need_honer = ob->query_need_honer();
		string race;
		if(flag == 0){
			s += ob->query_name_cn()+"\n";
			s += ob->query_picture_url()+"\n"+ob->query_desc()+"\n"+ob->query_content()+"\n";
			if(me->query_raceId() == "human")
				race = "仙气";
			else if(me->query_raceId() == "monst")
				race = "妖气";
			s += "需要"+race+"："+need_honer+"\n";
			if(need_num>0){
				s += "需要"+need_ob->query_name_cn()+":"+need_num+"块\n";
			}
			s +="--------\n";
			s += "[换取:honer_buy "+type+" "+filename+" "+need_name+" "+need_num+" 1]\n";
		}
		else if(flag == 1){
			if(me->honerpt<need_honer)
				s += "你的荣誉值不够\n";
			else{
				if(need_num>0){
					array(object) all_ob =all_inventory(me);
					int have_duihuan_item = 0;
					foreach(all_ob,object ob){
						if(ob->is_combine_item()&&ob->query_name()==need_name){
							have_duihuan_item += ob->amount;
						}
					}
					if(have_duihuan_item<need_num){
						s += "您没有足够的"+need_ob->query_name_cn()+"\n";
						s += "\n[返回:honer_equip_view "+type+"]\n";
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
					else{
						me->remove_combine_item(need_name,need_num);
					}
				}
				me->honerpt -= need_honer;
				s += "你获得了"+ob->query_name_cn()+"\n";
				ob->move(me);
			}
		}
	}
	else 
		s += "没有这样的物品\n";
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:honer_equip_view "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
