#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(arg)
		arg=replace(arg,(["%20":""]));                                                                                  
	else{
		s += "银行密码捐赠获取仙道玉\n";
		s += "注：请玩家汇款或者转帐后，务必保留汇款回执或者转帐订单流水号。\n";
		s += "如已汇款或转账，请致电客服获取捐赠密码，此密码只能使用一次。\n";
		s += "请输入你的银行捐赠密码：\n[int:add_big_fee ...]";

		s += "[购买说明:add_big_fee_des]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;                                                                                            
	}
	werror("----arg = "+arg+"----\n");
	if(arg&&arg!=""){
		for(int i=0;i<sizeof(arg);i++){
			if(arg[i]>=0&&arg[i]<=127)
				;//do_nothing
			else{
				arg = 0;
				s = "您输入的捐赠密码不符合规范，请返回重试。\n";
				s += "[返回游戏:look]\n";
				return 1;
			}
		}
	}


	object obt= System.Time();
	int st = obt->usec_full;

	int ivr_account;

	string arg_log=replace(arg," ","_");
	sscanf(arg,"%d",ivr_account);

	array(mapping(string:mixed)) result_info = DBD->query_bigfee_info(ivr_account);
	if(sizeof(result_info))
	{
		DBD->updateStatus_big(me->name,ivr_account);
		int feepoint = (int)result_info[0]["fee"];
		int feegift = (int)result_info[0]["fee_gift"];
		string Uid = me->name;
		int feetotal = feepoint + feegift;
		int type_sy_num = 0;
		int type_xyy_num = 0;
		int type_lly_num = 0;
		int type_bly_num = 0;
		int type_xtby_num = 0;

		type_xtby_num = feetotal/10000;  //玄天宝玉
		feetotal = feetotal%10000;
		type_bly_num = feetotal/1000;    //碧銮玉
		feetotal = feetotal%1000;
		type_lly_num = feetotal/100;     //玲珑玉
		feetotal = feetotal%100;
		type_xyy_num = feetotal/10;      //仙缘玉
		type_sy_num = feetotal%10;       //碎玉 

		object yushi;
		string s_log = "";
		string now=ctime(time());
		s +="恭喜，你已经通过捐赠获得";
		if(type_xtby_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"xuantianbaoyu");
			};
			if(!err && yushi){
				yushi->amount = type_xtby_num;
				yushi->move_player(me->query_name());
				s += type_xtby_num + "块【玉】玄天宝玉   ";
				s_log = me->query_name_cn()+"("+me->query_name()+")通过捐赠密码("+arg+")大额购买获取"+ type_xtby_num+"块玄天宝玉\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!大额购买时获取玄天宝玉"+ type_xtby_num+"块失败\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}

		if(type_bly_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"biluanyu");
			};
			if(!err && yushi){
				yushi->amount = type_bly_num;
				yushi->move_player(me->query_name());
				s += type_bly_num + "块【玉】碧銮玉   ";
				s_log = me->query_name_cn()+"("+me->query_name()+")通过捐赠密码("+arg+")大额购买获取"+ type_bly_num+"块碧銮玉\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!大额购买时获取碧銮玉"+ type_bly_num+"块失败\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}


		if(type_lly_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"linglongyu");
			};
			if(!err && yushi){
				yushi->amount = type_lly_num;
				yushi->move_player(me->query_name());
				s += type_lly_num + "块【玉】玲珑玉   ";
				s_log = me->query_name_cn()+"("+me->query_name()+")通过捐赠密码("+arg+")大额购买获取"+ type_lly_num+"块玲珑玉\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!大额购买时获取玲珑玉"+ type_lly_num+"块失败\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}


		if(type_xyy_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"xianyuanyu");
			};
			if(!err && yushi){
				yushi->amount = type_xyy_num;
				yushi->move_player(me->query_name());
				s += type_xyy_num + "块【玉】仙缘玉   ";
				s_log = me->query_name_cn()+"("+me->query_name()+")通过捐赠密码("+arg+")大额购买获取"+ type_xyy_num+"块仙缘玉\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!大额购买时获取仙缘玉"+ type_xyy_num+"块失败\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}


		if(type_sy_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"suiyu");
			};
			if(!err && yushi){
				yushi->amount = type_sy_num;
				yushi->move_player(me->query_name());
				s += type_sy_num + "块【玉】块碎玉";
				s_log = me->query_name_cn()+"("+me->query_name()+")通过捐赠密码("+arg+")大额购买获取"+ type_sy_num+"块碎玉\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!大额购买时获取碎玉"+ type_sy_num+"块失败\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}
		s += "!\n";
		s += "[返回游戏:look]\n";	
		write(s);
		return 1;
	}
	else{
		s += "抱歉，没有你的购买记录，请确认输入了正确的捐赠密码，并查实是否已获取过物品。如仍有问题请与客服联系。\n";
		s += "[重新输入:add_big_fee.pike]\n";
		s += "[返回游戏:look]\n";	
		write(s);
		return 1;
	}
}
