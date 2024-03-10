#include <command.h>
#include <gamelib/include/gamelib.h>
//arg 
//此指令确认熔炼，并且生成新的物品
int main(string arg)
{
	string s = "";
	int yushi_flag = 0;
	yushi_flag=(int)arg;
	object me=this_player();
	if(me->vice_skills["duanzao"] == 0)
		s += "你现在并不会锻造技能\n";
	else{
		mapping(int:array) tmp_list = me->ronglian_list;
		if(sizeof(tmp_list) != 2)
			s += "需要两件精致或精致以上的物品才能完成熔炼\n";
		else{
			array tmp_arr1 = tmp_list[1];
			array tmp_arr2 = tmp_list[2];
			object add_item1 = present(tmp_arr1[0],me,tmp_arr1[1]);
			object add_item2 = present(tmp_arr2[0],me,tmp_arr2[1]);
			if(!add_item1 || !add_item2)
				s += "你身上没有参与熔炼的物品\n";
			else{
				string yushi_name ="";
				string yushi_name_cn ="";
				if(yushi_flag != 0){
					//如果是用玉石辅助，则需要判断是否身上有此种玉石	
					array(object) all_obj = all_inventory(me);
					switch(yushi_flag){
						case 1:
							yushi_name="ganlanshi";
							yushi_name_cn="橄榄石";
							break;
						case 2:
							yushi_name="lvsongshi";
							yushi_name_cn="绿松石";
							break;
						case 3:
							yushi_name="jianjingshi";
							yushi_name_cn="尖晶石";
							break;
						case 4:
							yushi_name="qingjinshi";
							yushi_name_cn="青金石";
							break;
						default:
							break;
					}
					int have_yushi = 0;
					foreach(all_obj,object ob){
						if(ob && ob->query_name()==yushi_name){
							have_yushi = 1;
							break;
						}
					}
					if(!have_yushi){
						s += "无法炼化！你身上没有"+yushi_name_cn+"\n"; 
						s += "[返回:viceskill_ronglian_list]\n";
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
				}

				object get_item = RONGLIAND->get_ronglian_item(add_item1,add_item2,yushi_flag);
				if(get_item){
					string now=ctime(time());
					string s_file = file_name(get_item);
					string log_s = "";
					array(int) skill = me->vice_skills["duanzao"];
					s += "熔炼成功！\n";
					s += "你得到["+get_item->query_name_cn()+":inv_other "+s_file+"]\n";
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
					if(yushi_flag != 0){ //扣除相应的宝石
						me->remove_combine_item(yushi_name,1);
					}
					log_s += add_item1->query_name_cn()+"和"+add_item2->query_name_cn()+"熔炼得到"+get_item->query_name_cn();
					add_item1->remove();
					add_item2->remove();
					get_item->move(me);
					me->ronglian_list = ([]);
					Stdio.append_file(ROOT+"/log/ronglian.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+")："+log_s+"\n");
				}
				else{
					s += "熔炼失败！\n";
					s += "必须要两个精致以上的物品才能参与熔炼\n";
					s += "首饰是不能与武器或防具熔炼。\n";
				}
			}
			//}
	}
}
s += "\n[继续熔炼:viceskill_ronglian_list 0]\n";
s += "[返回游戏:look]\n";
write(s);
//me->write_view(WAP_VIEWD["/emote"],0,0,s);
//write(s);
return 1;
}
