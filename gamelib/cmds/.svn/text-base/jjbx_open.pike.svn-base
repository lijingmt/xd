#include <command.h>
#include <gamelib/include/gamelib.h>


//此指令用于实现打开精金宝箱的功能，获得三种公共物品：冰蓝玉石或者紫晶玉石，
//和玩家等级相仿的装备，仙缘玉石; 此外30级以下的玩/家还会获得特药

int main(string arg){
	object me = this_player();
	object bx;
	string bx_name = "";
	string s = "";
	string s_log = "";
	int bx_count = 0;
	sscanf(arg,"%s %d",bx_name,bx_count);
	bx = present(bx_name,me,bx_count);
	if(bx){
		string now = ctime(time());
		int yu_amount = 0;
		int att_num = 0;//装备属性个数
		int user_level = me->query_level();
		int yushi_ran = random(100);
		string yushi_name = "";
		string yu_name = "";
		string equip_name = ITEMSD->get_itemname_on_level(user_level);
		object yushi,yu,equip;
		s += "恭喜！您获得了:\n";
		//分配玉石
		if(yushi_ran<15){
			yushi_name = "zijinyushi";
		}
		else {
			yushi_name = "binglanyushi";
		}
		//分配仙缘玉
		int yu_ran = random(100);
		if(yu_ran>=0&&yu_ran<35){
			yu_name = "xianyuanyu";
			yu_amount = 2;
		}
		else if(yu_ran>=35&&yu_ran<65){
			yu_name = "xianyuanyu";
			yu_amount = 5;
		}
		else if(yu_ran>=65&&yu_ran<85){
			yu_name = "xianyuanyu";
			yu_amount = 8;
		}
		else if(yu_ran>=85&&yu_ran<95){
			yu_name = "linglongyu";
			yu_amount = 1;
		}
		else if(yu_ran>=95&&yu_ran<100){
			yu_name = "linglongyu";
			yu_amount = 2;
		}
		//装备
		int equip_ran = random(100);
		if(equip_ran>=0&&equip_ran<60){
			att_num = 3 + random(2);
			if(!att_num) att_num = 3;
		}
		else if(equip_ran>=60&&equip_ran<80){
			att_num = 5;
		}
		else if(equip_ran>=80&&equip_ran<95){
			att_num = 6;
		}
		else if(equip_ran>=95&&equip_ran<100){
			att_num = 7;
		}
		if(equip_name&&att_num){
			equip = ITEMSD->get_convert_item(equip_name,att_num);
		}
		mixed err = catch{
			yushi = clone(ITEM_PATH+"yushi/"+yushi_name);
			yu = clone(ITEM_PATH+"yushi/"+yu_name);
		};
		if(!err && yushi && yu && equip){
			yu->amount = yu_amount;
			s += yushi->query_short()+"\n"+yu->query_short()+"\n"+equip->query_short()+"\n";
			s_log += me->query_name_cn()+"("+me->query_name()+") 打开"+bx->query_name_cn()+"时获得"+yushi->query_short()+","+yu->query_short()+","+equip->query_short();
			yushi->move(me);
			yu->move(me);
			equip->move(me);
		}
		//30级以下玩家给予经验特药
		if(user_level<30){
			string teyao_name = "";
			int teyao_ran = random(100);
			object teyao;
			if(teyao_ran>=0&&teyao_ran<35){
				teyao_name = "yanghuaimi";
			}
			else if(teyao_ran>=35&&teyao_ran<65){
				teyao_name = "wuhuaguo";
			}
			else if(teyao_ran>=65&&teyao_ran<85){
				teyao_name = "xiangmuguo";
			}
			else if(teyao_ran>=85&&teyao_ran<95){
				teyao_name = "zisangshen";
			}
			else if(teyao_ran>=95&&teyao_ran<100){
				teyao_name = "tanxianglu";
			}
			mixed err1 = catch{
				teyao = clone(ITEM_PATH+"teyao/"+teyao_name);
			};
			if(!err1&&teyao){
				teyao->amount = 1;
				s += teyao->query_short()+"\n";
				s_log += "和"+teyao->query_short();
				teyao->move(me);
			}
		}
		/*
		//得到5枚十字章 added by caijie 080925
		int count = 0;
		string zhang_name = "";
		object zhang;
		array(int) rand = ({90,80,70,60,50,40}); //2～7级的十字章对应的开出概率
		while(count<5){
			zhang_name = "bossdrop/shizizhang1";
			mixed err1 = catch{
				zhang = clone(ITEM_PATH+zhang_name);
			};
			if(!err1&&zhang){
				s += zhang->query_short()+"\n";
				s_log += "和"+zhang->query_short();
				zhang->move_player(me->query_name());
			}
			count ++;
			for(int i=0;i<=5;i++){
				if(count>=5)break;
				int ran = random(100);
				if(ran<rand[i]){
					count ++;
					string lv = (string)(i+2);
					zhang_name = "bossdrop/shizizhang"+lv;//lv级十字章对应的文件名称
					mixed err1 = catch{
						zhang = clone(ITEM_PATH+zhang_name);
					};
					if(!err1&&zhang){
						s += zhang->query_short()+"\n";
						s_log += "和"+zhang->query_short();
						zhang->move_player(me->query_name());
					}
				}
			}
		}
		*/
		Stdio.append_file(ROOT+"/log/hyq_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		bx->remove();
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
