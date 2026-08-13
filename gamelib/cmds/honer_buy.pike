#include <command.h>
#include <gamelib/include/gamelib.h>
#define HONER ROOT "/gamelib/clone/item/honer/"
//arg = type name flag
// type为"duanzao" or "liandan" ;name为配方文件; flag为0表示察看，为1表示购买
string query_honer_name(string race_id)
{
	if(race_id == "human")
		return "仙气";
	if(race_id == "monst")
		return "妖气";
	if(race_id == "third")
		return "灵气";
	return "荣誉值";
}

int main(string|zero arg)
{
	string s = "荣誉属于真正的勇者\n";
	object me=this_player();
	string filename = "";
	string need_name = "";//兑换需要物品的名词
	int need_num = 0;//兑换需要物品的数量
	string type = "";
	int flag = 0;
	string producer_info = "";
	if(!arg || sscanf(arg,"%s %s %s %d %d",type,filename,need_name,need_num,flag)!=5 ||
	   (flag!=0 && flag!=1) || search(filename,"..")!=-1 ||
	   search(filename,"/")!=-1 ||
	   search(({"weapon","buyi","qingjia","zhongkai","decorate","spec"}),type)==-1){
		write("兑换参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	object env=environment(me);
	string room_race=env ? (string)env->room_race : "";
	string player_race=(string)me->query_raceId();
	string catalog_race=(player_race=="third" ? room_race : player_race);
	if((catalog_race!="human" && catalog_race!="monst") ||
	   room_race!=catalog_race){
		write("这里没有适合你的荣誉兑换。\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) offer=ITEMS_EXCHANGED->query_exchange_offer(
		catalog_race,type,filename);
	if((int)offer["ok"]){
		need_name=(string)offer["need_name"];
		need_num=(int)offer["need_num"];
	}
	else{
		write("该物品未在服务端兑换目录中。\n[返回游戏:look]\n");
		return 1;
	}
	object ob;
	mixed load_err=catch{ ob = clone(HONER+filename); };
	object need_ob;
	if(need_num>0)
		load_err=catch{ need_ob=clone(ITEM_PATH+"bossdrop/"+need_name); };
	if(!load_err && ob && ob->query_item_from()=="honer" &&
	   (int)ob->query_need_honer()>0 &&
	   has_prefix((string)ob->query_name_cn(),
		catalog_race=="human" ? "【仙】" : "【妖】")){
		int need_honer = ob->query_need_honer();
		string race;
		if(flag == 0){
			s += ob->query_name_cn()+"\n";
			s += ob->query_picture_url()+"\n"+ob->query_desc()+"\n"+ob->query_content()+"\n";
			race = query_honer_name(me->query_raceId());
			s += "需要"+race+"："+need_honer+"\n";
			if(need_num>0 && need_ob){
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
						mapping(string:mixed) removal=
							me->remove_combine_item_transaction(need_name,need_num);
						if(!(int)removal["ok"]){
							s += "兑换材料扣除失败\n";
							write(s+"[返回游戏:look]\n");
							return 1;
						}
						me->honerpt -= need_honer;
						if(ob->move(me)!=1 || environment(ob)!=me){
							me->honerpt += need_honer;
							me->rollback_combine_item_transaction(removal);
							s += "兑换失败，材料与荣誉值已退回\n";
						}
						else
							s += "你获得了"+ob->query_name_cn()+"\n";
						ob=0;
					}
				}
				if(need_num==0){
					me->honerpt -= need_honer;
					if(ob->move(me)!=1 || environment(ob)!=me){
						me->honerpt += need_honer;
						s += "兑换失败，荣誉值已退回\n";
					}
					else
						s += "你获得了"+ob->query_name_cn()+"\n";
				}
			}
		}
	}
	else 
		s += "没有这样的物品\n";
	if(need_ob)
		destruct(need_ob);
	if(ob && environment(ob)!=me)
		destruct(ob);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:honer_equip_view "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
