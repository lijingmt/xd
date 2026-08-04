#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM_PATH_KUANG ITEM_PATH "material/"                                     
#define GATHER_STACK_NUM 9999
#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd"))
//arg = name count
//采药调用指令
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	string name = "";
	int count = 0;
	string now=ctime(time());
	sscanf(arg,"%s %d",name,count);
	//if(me->vice_skills == 0)
	//	me->vice_skills = ([]);
	if(me->vice_skills["caiyao"] == 0)
		s += "你不会采药技能\n";
	else{
		object env = environment(this_player());
		object ob=present(name,env,count);
		//采矿会使影遁消失
		if(me->hind == 1)
			me->hind = 0;
		if(me->query_buff("spec",0) == "hind"){
			me->clean_buff("spec");
			m_delete(me["/danyao"],"spec");
		}
		if(ob){
				array(int) skill = me->vice_skills["caiyao"];
				int need_lev = CAOYAOD->query_need_level(name);
				if(need_lev < 0)
					s += "此草药被阴影所围绕，似乎不能挖掘\n";
				else{
					int now_lev = (int)skill[0];
					int now_count = (int)skill[1];
					if(now_lev < need_lev){
						s += "失败！\n";
						s += "需要采药技能熟练度"+need_lev+"才能挖掘"+ob->query_name_cn()+"\n";
					}
					else{
						string for_log = "";
						int got_any = 0;
						mapping(string:int) get_m = CAOYAOD->query_get_m(name);
						if(sizeof(get_m) > 0){
							foreach(indices(get_m),string get_name){
								int prob = get_m[get_name];
								if(prob == 100){
									object get_ob = clone(ITEM_PATH_KUANG+get_name);
								if(get_ob){
									int num = random(3)+1;
									string gathered_name = get_ob->query_name_cn();
									get_ob->amount = num;
									get_ob->max_count = GATHER_STACK_NUM;
									if(ARTISAND->store_gathered_material(me,get_ob)>0){
										s += "你采得"+num+gathered_name+"，已收入材料囊\n";
										for_log += "获得了"+num+gathered_name;
										got_any = 1;
									}
									else if(me->if_over_load(get_ob)){
										s += "背包已满且没有可合并的草药格，采药暂停。\n";
										get_ob->remove();
									}
									else{
										s += "你获得了"+num+get_ob->query_name_cn()+"\n";
										for_log += "获得了"+num+get_ob->query_name_cn();
										get_ob->move_player(me->query_name());
										got_any = 1;
									}
									}
									else
										s += "草药突然消失在一片烟雾中......\n";
								}
								else{
									if((random(100)+1)<prob){
									object get_ob = clone(ITEM_PATH_KUANG+get_name);
									if(get_ob){
										string gathered_name = get_ob->query_name_cn();
										get_ob->amount = 1;
										get_ob->max_count = GATHER_STACK_NUM;
										if(ARTISAND->store_gathered_material(me,get_ob)>0){
											s += "你采得一颗"+gathered_name+"，已收入材料囊\n";
											for_log += "，一颗"+gathered_name;
											got_any = 1;
										}
										else if(me->if_over_load(get_ob))
											get_ob->remove();
										else{
											s += "你获得了一颗"+get_ob->query_name_cn()+"\n";
											for_log += "，一颗"+get_ob->query_name_cn();
											get_ob->move_player(me->query_name());
											got_any = 1;
										}
										}
										else
											s += "草药突然消失在一片烟雾中......\n";
									}
								}
							}
							if(got_any){
								DAILYGOALD->record_gather(me);
								AUTOFIGHTD->consolidate_gathered_materials(me);
								if(for_log != "")
									Stdio.append_file(ROOT+"/log/caiyao.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+")："+for_log+"\n");
								ob->remove();
								//增加需要刷新此草药的数量
								CAOYAOD->set_flush_num(name);
								//检查熟练度是否升级
								mapping progress = ARTISAND->advance_proficiency(me,"caiyao",1);
								if((int)progress["new_level"]>now_lev)
									s += "你的采药技能熟练度提高到了"+
										(string)progress["new_level"]+"级\n";
							}
						}
					}
				}
		}
		else
			s += "该草药已被别人挖走!\n";
	}
	s += "[返回:look]\n";
	write(s);
	return 1;
}
