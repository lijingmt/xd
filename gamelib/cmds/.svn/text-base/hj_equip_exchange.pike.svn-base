#include <command.h>
#include <gamelib/include/gamelib.h>

/*********************************************************************************
 * 此指令实现用银色徽记换取装备的功能
 * arg 为空或者是装备前缀，分别有"youliang" "jingzhi" "shenlian" "tianjiang" "huanhua"
 ***********************************************************************************/

int main(string arg){
	object me = this_player();
	object item ;
	string item_pre = "";
	string item_name = "";
	string get_items = "";
	string s_log = "";
	string s = "";
	string now=ctime(time());
	int need_huiji = 0;
	int flag = 0;
	int attr_num = 0;
	int user_level = me->query_level();
	int huiji_count = 0;
	if(!arg){
		s += "清选择您要兑换的物品\n\n";
		s += "[兑换优良装备:hj_equip_exchange youliang]\n";
		s += "[兑换精致装备:hj_equip_exchange jingzhi]\n";
		s += "[兑换神炼装备:hj_equip_exchange shenlian]\n";
		s += "[兑换天降装备:hj_equip_exchange tianjiang]\n";
		s += "[兑换幻化装备:hj_equip_exchange huanhua]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && ob->query_name() == "yinsehuiji"){
			huiji_count += ob->amount;
		}
	}
	if(user_level<15){
		s += "只有15级以上的玩家才能兑换物品，您的等级不够，去修炼几天再来吧";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(arg == "youliang"){
	    attr_num = 1+random(2);
	    if(user_level>=15 && user_level<=34){
		if(huiji_count>=10){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 1;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",10);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取优良装备至少需要10个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	   if(user_level>=35 && user_level<=49){
	   	if(huiji_count>=30){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 1;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",30);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取优良装备至少需要30个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	if(user_level>=50){
	   	if(huiji_count>=60){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 1;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",60);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取优良装备至少需要60个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	}
	if(arg == "jingzhi"){
	    attr_num = 3+random(2);
	    if(user_level>=15 && user_level<=34){
		if(huiji_count>=15){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 3;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",15);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取精致装备至少需要15个银色徽记，您身上的银色徽记不够\n";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	   if(user_level>=35 && user_level<=49){
	   	if(huiji_count>=45){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 3;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",45);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取精致装备至少需要45个银色徽记，您身上的银色徽记不够\n";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	if(user_level>=50){
	   	if(huiji_count>=90){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 3;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",90);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取精致装备至少需要90个银色徽记，您身上的银色徽记不够\n";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	}
	if(arg == "shenlian"){
	    attr_num = 5;
	    if(user_level>=15 && user_level<=34){
		if(huiji_count>=25){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 5;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",25);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取神炼装备至少需要25个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	   if(user_level>=35 && user_level<=49){
	   	if(huiji_count>=75){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 5;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",75);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取神炼装备至少需要75个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	if(user_level>=50){
	   	if(huiji_count>=150){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 5;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",150);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取神炼装备至少需要150个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	}
	if(arg == "tianjiang"){
	    attr_num = 6;
	    if(user_level>=15 && user_level<=34){
		if(huiji_count>=35){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 6;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",35);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取天降装备至少需要35个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	   if(user_level>=35 && user_level<=49){
	   	if(huiji_count>=105){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 6;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",105);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取天降装备至少需要105个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	if(user_level>=50){
	   	if(huiji_count>=210){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 6;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",210);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取天降装备至少需要210个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	}
	if(arg == "huanhua"){
	    attr_num = 7;
	    if(user_level>=15 && user_level<=34){
		if(huiji_count>=50){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 7;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",50);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取幻化装备至少需要50个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	   if(user_level>=35 && user_level<=49){
	   	if(huiji_count>=150){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 7;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",150);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取幻化装备至少需要150个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	if(user_level>=50){
	   	if(huiji_count>=300){
		    item_name = ITEMSD->get_itemname_on_level(user_level);
		    if(item_name && item_name != ""){
			//获得属性个数
			if(!attr_num)
   			attr_num = 7;
			item = ITEMSD->get_convert_item(item_name,attr_num);
		 	if(item){
		    	    get_items += "|"+item->query_name();
		    	    s += "你得到了"+item->query_short()+"\n";
		    	    item->move(me);
		   	    me->remove_combine_item("yinsehuiji",300);
			    s_log += me->query_name_cn()+"("+me->query_name()+")用银色徽记换取装备得"+get_items+"\n";
  			    Stdio.append_file(ROOT+"/log/huiji_duihuan.log",now[0..sizeof(now)-2]+":"+s_log);

			}
	    	   }
		}
		else {
			s += "要换取幻化装备至少需要300个银色徽记，您身上的银色徽记不够";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	   }
	}
}

