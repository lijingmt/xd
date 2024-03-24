#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	int num = (int)arg;
	int have = 0;
	object me = this_player();

	if(random(100)<90){
		if(!me["/tmp/atk_ctime"])
			me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
		else{
			if( ((System.Time()->usec_full)/1000 - me["/tmp/atk_ctime"]) <= 1500 ){
				//werror("-------- player["+me->name+"] use_toolbar difftime<=1000 --------\n");
				if(!me["/tmp/wg_times"]) me["/tmp/wg_times"] = 1;
				else me["/tmp/wg_times"]++;
			}
			else{
				me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
			}
		}
	}

	
	
	mapping(string:int) tmp = me->query_toolbar(num);	
	string tmp_name = "";
	foreach(indices(tmp),string key){
		tmp_name = key;
		break;
	}
	if(tmp_name == "none" || tmp_name == "" )
		tell_object(me,"你并未配置快捷键"+(num+1)+"\n");
	else{
		if(me->in_combat){
			if(tmp[tmp_name]==1){
				//若配置的是技能
				me->perform(tmp_name);
				me->reset_view(WAP_VIEWD["/fight"]);
				me->write_view();
				return 1;
			}
			else if(tmp[tmp_name]==2){
				if(me->eat_timeCold == 0){
					//若配置的是食物
					array(object) items=all_inventory(me); 
					if(items&&sizeof(items)){
						foreach(items,object item){
							if(tmp_name == item->query_name()){
								string item_name = item->query_name_cn();
								int drk = item->eat();
								switch(drk){
									case 0:
										tell_object(me,"你的等级不够，不能食用 "+item_name+" 。\n");	
										break;
									case 1:
										tell_object(me,"你食用了 "+item_name+" 。\n");
										me->eat_timeCold = 20;
										have = 1;
										break;
									case 2:
										tell_object(me,"你的职业不能食用该物品。\n");
										break;
									case 3:
										tell_object(me,"你的阵营不能食用该物品。\n");
										break;
									case 4:
										tell_object(me,"你要食用什么物品？\n");
										break;
									case 5:
										tell_object(me,"你现在的状态不能食用该物品。\n");
										break;
									case 11:
										tell_object(me,"你已经到达生命上限，不用食用该物品。\n");
										break;
									case 22:
										tell_object(me,"你已经到达法力上限，不用饮用该物品。\n");
										break;
								}
								break;
							}
						}
					}
					if(!have)
						tell_object(me,"你已经用完了此物品\n");
					me->reset_view(WAP_VIEWD["/fight"]);
					me->write_view();
					return 2;
				}
				else{
					tell_object(me,"还有"+me->eat_timeCold+"秒才能食用\n");	
					me->reset_view(WAP_VIEWD["/fight"]);
					me->write_view();
					return 0;
				}
			}
			else if(tmp[tmp_name]==3){
				//若配置的是水
				if(me->eat_timeCold == 0){
					array(object) items=all_inventory(me); 
					if(items&&sizeof(items)){
						foreach(items,object item){
							if(tmp_name == item->query_name()){
								string item_name = item->query_name_cn();
								int drk = item->drink();
								switch(drk){
									case 0:
										tell_object(me,"你的等级不够，不能饮用 "+item_name+" 。\n");	
										break;
									case 1:
										tell_object(me,"你饮用了 "+item_name+" 。\n");
										me->eat_timeCold = 20;
										have = 1;
										break;
									case 2:
										tell_object(me,"你的职业不能饮用该物品。\n");
										break;
									case 3:
										tell_object(me,"你的阵营不能饮用该物品。\n");
										break;
									case 4:
										tell_object(me,"你要饮用什么物品？\n");
										break;
									case 5:
										tell_object(me,"你现在的状态不能饮用该物品。\n");
										break;
									case 11:
										tell_object(me,"你已经到达生命上限，不用食用该物品。\n");
										break;
									case 22:
										tell_object(me,"你已经到达法力上限，不用饮用该物品。\n");
										break;
								}
								break;
							}
						}
					}
					if(!have)
						tell_object(me,"你已经用完了此物品\n");
					me->reset_view(WAP_VIEWD["/fight"]);
					me->write_view();
					return 3;
				}
				else{
					tell_object(me,"还有"+me->eat_timeCold+"秒才能饮用\n");	
					me->reset_view(WAP_VIEWD["/fight"]);
					me->write_view();
					return 0;
				}
			}
		}
		else{
			me->reset_view(WAP_VIEWD["/look"]);
			me->write_view();
			return 0;
		}
	}
	return 0;
}
