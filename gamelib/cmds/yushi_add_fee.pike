#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//短信捐赠调用的接口
//arg = fee yushi_level
int main(string arg)
{
	//con->write("login_fee "+PROJECT+" "+mobile+"\n");
	//con->write("yushi_add_fee "+fee+" "+yushi_level+" "+spec_fg+"\n");
	//50 2 szx = 充值50元，获得类型为2的仙缘玉50个（1元=1仙缘玉）
	object me = this_player();
	object yushi; 
	int fee = 0;
	int yushi_level = 1;
	string yushi_type = "";
	string spec_fg = "";
	sscanf(arg,"%d %d %s",fee,yushi_level,spec_fg);
	string now=ctime(time());
	string s_log = "";
	if(fee <= 0){
		s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error! 购买个数为0的物品\n";
		Stdio.append_file(ROOT+"/log/fee_log/addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		return 1;
	}
	//mudlib/include/mudlib.h:#define STACK_NUM		30//复数物品的堆叠数目上限
	if(fee > STACK_NUM && yushi_level < 5){
		me->all_fee += fee;//记录玩家的捐赠总数
		int up_fee = fee/10;
		fee = fee%10;
		int up_yushi_level = yushi_level+1;
		me->command("yushi_add_fee "+up_fee+" "+up_yushi_level);
		if(fee > 0)
			me->command("yushi_add_fee "+fee+" "+yushi_level);
	}
	else{
		//([1:"suiyu",2:"xianyuanyu",3:"linglongyu",4:"biluanyu",5:"xuantianbaoyu"]);//玉石稀有度与玉石的对应表
		yushi_type = YUSHID->get_yushi_name(yushi_level);
		me->all_fee += fee;//记录玩家的捐赠总数
		while(fee > STACK_NUM){
			mixed err=catch{
				yushi = clone(YUSHI_PATH+yushi_type);
			};
			if(!err && yushi){
				yushi->amount = STACK_NUM;
				yushi->move_player(me->query_name());
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error! 购买时无法获得物品\n";
				Stdio.append_file(ROOT+"/log/fee_log/addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			fee = fee - STACK_NUM;
		}
		if(fee > 0){
			mixed err=catch{
				yushi = clone(YUSHI_PATH+yushi_type);
			};
			if(!err && yushi){
				yushi->amount = fee;
				yushi->move_player(me->query_name());
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error! 购买时无法获得物品\n";
				Stdio.append_file(ROOT+"/log/fee_log/addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
		}
	}
	//特殊标识表示有其他物品赠送
	if(spec_fg == "szx"){
	/*
		//神州行50捐赠送宝箱一个，08/03/04开始的活动
		object baoxiang;
		mixed err = catch{
			baoxiang = clone(ITEM_PATH+"baoxiang/jinsibaoshidai");
		};
		if(!err&&baoxiang){
			baoxiang->move(me);
		}
	*/
		//神州行50捐赠送精金宝箱一个和火月签五支，08/04/16 add by caijie
	        object baoxiang;                                                                                             
                object huoyueqian;
		mixed err = catch{
		         baoxiang = clone(ITEM_PATH+"baoxiang/jingjinbaoxiang");
		         huoyueqian = clone(ITEM_PATH+"bossdrop/huoyueqian");
		};
		if(!err&&baoxiang&&huoyueqian){
		         baoxiang->move(me);
		         huoyueqian->amount=5;
			 huoyueqian->move(me);
		}
	       //add by caijie end
	}
	return 1;
}
