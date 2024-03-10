#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM_PATH_KUANG ITEM_PATH "material/"                                     
//arg = name count
//采药调用指令
int main(string arg)
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
			if(me->if_over_load(ob)){
				s += "你随身物品已满，无法再存放更多的东西\n\n";
			}
			else{
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
						mapping(string:int) get_m = CAOYAOD->query_get_m(name);
						if(sizeof(get_m) > 0){
							foreach(indices(get_m),string get_name){
								int prob = get_m[get_name];
								if(prob == 100){
									object get_ob = clone(ITEM_PATH_KUANG+get_name);
									if(get_ob){
										int num = random(3)+1;
										s += "你获得了"+num+/*get_ob->query_unit()+*/get_ob->query_name_cn()+"\n";
										for_log += "获得了"+num+get_ob->query_name_cn();
										get_ob->amount = num;
										get_ob->move_player(me->query_name());
									}
									else
										s += "草药突然消失在一片烟雾中......\n";
								}
								else{
									if((random(100)+1)<prob){
										object get_ob = clone(ITEM_PATH_KUANG+get_name);
										if(get_ob){
											s += "你获得了一颗"+get_ob->query_name_cn()+"\n";
											for_log += "，一颗"+get_ob->query_name_cn();
											get_ob->amount = 1;
											get_ob->move_player(me->query_name());
										}
										else
											s += "草药突然消失在一片烟雾中......\n";
									}
								}
							}
							if(for_log != "")
								Stdio.append_file(ROOT+"/log/caiyao.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+")："+for_log+"\n");
							ob->remove();
							//增加需要刷新此草药的数量
							CAOYAOD->set_flush_num(name);
							//检查熟练度是否升级
							if(now_lev < skill[2]){
								int update_need = (int)(now_lev/5);
								if(now_count>=update_need){
									skill[0]++;
									skill[1]=0;
									s += "你的采药技能熟练度提高到了"+(now_lev+1)+"级\n";
								}
								else
									skill[1]++;
							}
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
