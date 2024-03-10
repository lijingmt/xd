#include <command.h>
#include <gamelib/include/gamelib.h>

//砸门

int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "";
	string s_log = "";//日志
	array(mixed) a = room->query_door()/",";//门
	string dr_name = a[1];//门
	string hm_name = arg;//锤子
	//sscanf(arg,"%s %s",dr_name,hm_name);
	object dr_ob = (object)(ITEM_PATH+dr_name);
	//object hm_ob = (object)(ITEM_PATH+hm_name);
	//object hammer = present(hm_ob->query_name(),me,0);
	object hammer = present(hm_name,me,0);
	if(!hammer){
		s += "- -!您身上没有这种锤子\n";
		s += "\n[返回:door_destroy_entry]\n";
		//s += "\n[返回:door_destroy_entry "+dr_name+"]\n";
		s += "[返回游戏:look]\n";
	}
	else if(!dr_ob){
		s += "这家不存在这种门\n";
		s += "\n[返回:popview]\n";
		s += "[返回游戏:look]\n";
	}
	else {
		s += "你拿出一把"+hammer->query_name_cn()+"一阵狂砸...\n\n";
		int dr_sol = dr_ob->value;//门的坚固度
		int hm_sol = hammer->value;//锤子的坚固度
		int range = 0;
		if(dr_sol>0)
			range = (int)hm_sol*10000/(dr_sol*2);//砸门概率范围
		int ran = random(10000);
		if(ran<range){
			s += "你的锤子坏了!\n不过门开了!\n";
			s += "\n";
			s += "[四下张望,偷偷进门:home_enter main]\n";
			s += "[赶紧离开:home_leave "+ room->query_slotName()+" "+room->query_flatName() +"]\n";
			me->home_rights[2]=room->query_masterId();
			string time = (string)time();
			HOMED->save_door("2,"+time+","+me->query_name());
			HOMED->give_master_msg(room,me,"你家的大门被"+me->query_name_cn()+"砸开了，快点回去抓强盗吧\n");
		}
		else {
			s += "您的锤子坏了，但门没被砸开，看来这家的门很坚固啊~\n";
			s += "\n";
			s += "[继续砸门:door_destroy_detail]\n";
			s += "[赶紧离开:look]\n";
		}
		me->remove_combine_item(hm_name,1);
	}
	write(s);
	return 1;
}
