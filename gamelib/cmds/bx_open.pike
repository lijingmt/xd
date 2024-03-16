#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
#define BAOXIANG_PATH ROOT "/gamelib/clone/item/baoxiang/"
#define YAOSHUI_PATH ROOT "/gamelib/clone/item/liandan/"
#define BAOSHI_PATH ROOT "/gamelib/clone/item/baoshi/"
//圣诞活动，打开宝箱获得物品的方法。

int main(string arg)
{
	object me = this_player();
	string bx_name="";
	int bx_count= 0;

	string desc="";
	sscanf(arg,"%s %d",bx_name,bx_count);
	object bx = present(bx_name,me,bx_count);
	if(bx)
	{
		object xx;           //圣诞星星
		object yushi;        //碎玉
		object yaoshui;      //药水
		object baoshi;      //宝石，added by caijie 08/12/15
		string s_log = "";
		int yushi_num = 1;
		string yushi_type = "suiyu";
		string yushi_type_cn = "碎玉";
		string now = ctime(time());

		int rate = 200;//获得玉石和星星的概率
		int bs_rate = 500;//获得宝石的概率added by caijie 08/12/15
		int bx_level = bx->query_item_level();

		desc += "恭喜，你获得了:\n";
		//获取一瓶特殊的药水
		array(string) yaoshui_list = ({"christmas/ningliwan","christmas/ningfalu","christmas/cuipingjiang","christmas/lingdonglu","christmas/bishuilu","christmas/qingyulu","christmas/ziyunsan","christmas/lingyujiang","christmas/liefengdan","christmas/danqiongjiang"});
		array(string) baoshi_list = ({"christmas/xuehongchuoshi","christmas/xuejingfantie","christmas/xuejingtaijin","christmas/xuejingtieshi","christmas/xuejingxuantie","christmas/xuejingyuntie","christmas/xuejingwujin","christmas/xuejingjianshi","christmas/xuehuojingshi","christmas/jingfengjingshi","christmas/jingyueliangshi","christmas/jingliujinshi","christmas/jinghuangshuiyu","christmas/jingqingtongshi","christmas/jingjingbojin","christmas/jingjingyjinshi","christmas/jingxuanhuangshi","christmas/jingroujinshi","christmas/bingbaijingshi","christmas/bingbingjingshi","christmas/bingshuijianjing","christmas/bingqingyueshi","christmas/bingjinglvshi","christmas/bingjingxinshi","christmas/bingjingyinshi","christmas/bingmaoyanshi","christmas/bingzihupo"});
		mixed err=catch{
			yaoshui = clone(YAOSHUI_PATH + yaoshui_list[random(sizeof(yaoshui_list))]);
		};
		if(!err && yaoshui){
		//	werror("============= error when get YS===========");
			yaoshui->amount = 1;
			s_log = me->query_name_cn()+"("+me->query_name()+") 开启圣诞宝箱时获得1瓶"+ yaoshui->query_name_cn()+"\n";
			Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			desc +="一瓶" + yaoshui->query_name_cn()+"\n";
			yaoshui->move_player(me->query_name());
		}
		else{
			s_log = me->query_name_cn()+"("+me->query_name()+")  error! 开启圣诞宝箱时获取"+yaoshui->query_name_cn()+"失败\n";
			Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		}



		switch(bx_level)//依据不同的宝箱等级，确定不同的物品掉率。
		{
			case 1:
				rate = 2;
				bs_rate = 500;
				break;
			case 2:
				rate = 4;
				break;
				bs_rate = 1000;
			case 3:
				rate = 6;
				bs_rate = 1500;
				break;
			case 4:
				rate = 8;
				bs_rate = 2000;
				break;
			case 5:
				rate = 10;
				bs_rate = 2500;
				break;
			case 6:
				rate = 12;
				bs_rate = 3000;
				break;
			case 7:
				rate = 14;
				bs_rate = 3500;
				break;
			default:
				rate=2;
				bs_rate = 500;
		}

		//rate = bs_rate = 10000;//测试用
		if(random(10000)<=rate)//得到一颗星星
		{
			mixed err=catch{
				xx = clone(BAOXIANG_PATH+"chr_xx");
			};
			if(!err && xx){
				xx->amount = 1;
				xx->move_player(me->query_name());
				s_log = me->query_name_cn()+"("+me->query_name()+")  开启圣诞宝箱时获得1颗圣诞星星\n";
				Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+")  error! 开启圣诞宝箱时获得圣诞星星失败\n";
				Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			desc +="一颗【圣】圣诞星星\n";
		}
		if(random(10000)<=rate)//得到一颗碎玉
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+yushi_type);
			};
			if(!err && yushi){
				yushi->amount = 1;
				yushi->move_player(me->query_name());
				s_log = me->query_name_cn()+"("+me->query_name()+") 开启圣诞宝箱时获得1块碎玉\n";
				Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+")  error! 开启圣诞宝箱时无法获得碎玉\n";
				Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			desc +="一块【玉】碎玉\n";
		}
		if(random(10000)<=bs_rate)//得到一颗宝石
		{
			int drop_fg = 1;
			int bs_ind = random(sizeof(baoshi_list));
			if(baoshi_list[bs_ind]=="christmas/jinghuangshuiyu"){
				if(random(100)>=5){
					drop_fg = 0;
				}
			}
			if(drop_fg){
				mixed err=catch{
					baoshi = clone(BAOSHI_PATH+baoshi_list[bs_ind]);
				};
				if(!err&&baoshi){
					baoshi->amount = 1;
					s_log = me->query_name_cn()+"("+me->query_name()+")  开启圣诞宝箱时获得"+baoshi->query_short()+"\n";
					desc += baoshi->query_short()+"\n";
					baoshi->move_player(me->query_name());
					Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				}
				else{
					s_log = me->query_name_cn()+"("+me->query_name()+")  error! 开启圣诞宝箱时无法获得宝石\n";
					Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				}
			}
		}
		bx->remove();
	}
	else
		desc += "你身上没有这件物品！\n";
	desc += "[返回游戏:look]\n";
	write(desc);
	return 1;
}
