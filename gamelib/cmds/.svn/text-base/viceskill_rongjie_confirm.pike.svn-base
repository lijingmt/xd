#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = flag name count
//flag = 0 列出物品属性，然后等待用户再次确认
//flag = 1 熔解物品
//此指令确定熔解
int main(string arg)
{
	string s = "";
	object me=this_player();
	int flag = 0;
	string name = "";
	int count = 0;
	int can_get = 0; //可以获得熔解后的物品的标识，主要是针对随身物品是否已满
	sscanf(arg,"%d %s %d",flag,name,count);
	object ob=present(name,me,count);
	object kuang;
	object baoshi;
	if(!ob){
		s += "你身上已没有该物品\n";
		s += "\n[继续熔解:viceskill_rongjie_list]\n";
	}
	else if(flag == 0){
		s += ob->query_name_cn()+"\n";
		s += ob->query_desc()+"\n";
		s += ob->query_content()+"\n";
		s += "[熔解:viceskill_rongjie_confirm 1 "+name+" "+count+"]\n";
		s += "\n[返回:viceskill_rongjie_list]\n";
	}
	else if(flag == 1){
		//获得熔解产物
		int rare_level = ob->query_item_rareLevel();
		if(ob->query_item_from() != "")
			rare_level = 7;
		array(object) get_items = RONGJIED->get_rongjie_items(ob->query_item_canLevel(),rare_level);
		kuang = get_items[0];
		//kuang = RONGJIED->get_kuang(ob->query_item_canLevel());
		//baoshi = RONGJIED->get_baoshi(ob->query_item_canLevel(),rare_level);
		if(sizeof(get_items) > 1)
			baoshi = get_items[1];
		if(me->if_over_easy_load() == 1){
			if(me->if_over_load(kuang) == 0){
				if(baoshi){
					if(me->if_over_load(baoshi) == 0){
						can_get = 1;
					}
				}
				else 
					can_get = 1;
			}
		}
		else 
			can_get = 1;
		if(can_get){
			string now=ctime(time());
			string log_s = "";
			s += "熔解成功！\n";
			s += "你得到了"+kuang->amount+"块"+kuang->query_name_cn()+" ";
			log_s += "熔解"+ob->query_name_cn()+",得到了"+kuang->amount+"块"+kuang->query_name_cn()+" ";
			kuang->move_player(me->query_name());
			if(baoshi){
				s += "和 "+baoshi->amount+"颗"+baoshi->query_name_cn()+"\n";
				log_s += "和 "+baoshi->amount+"颗"+baoshi->query_name_cn()+"\n";
				baoshi->move_player(me->query_name());
			}
			else{
				s += "\n";
				log_s += "\n";
			}
			Stdio.append_file(ROOT+"/log/rongjie.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+")："+log_s+"\n");
			ob->remove();
			s += "\n[继续熔解:viceskill_rongjie_list]\n";
		}
		else
			s += "你随身物品已满，无法再存放更多的东西\n\n";
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
