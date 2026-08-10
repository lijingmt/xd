#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
#define BAOXIANG_PATH ROOT "/gamelib/clone/item/baoxiang/"
//神州行捐赠送宝石袋，这是打开宝石袋获得物品的指令。物品包括了两中玉石:紫金玉石和冰蓝玉石

int main(string|zero arg)
{
	object me = this_player();
	string bx_name="";
	int bx_count= 0;

	string desc="";
	if(!arg || sscanf(arg,"%s %d",bx_name,bx_count)!=2 ||
	   bx_name!="jinsibaoshidai" || bx_count<0){
		write("打开参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	object bx = present(bx_name,me,bx_count);
	if(bx && (file_name(bx)/"#")[0]==ITEM_PATH+"baoxiang/jinsibaoshidai")
	{
		string box_name_cn=(string)bx->query_name_cn();
		// 先消耗真实宝石袋，防止奖励发放后异常导致重复开启。
		bx->remove();
		string spec_yushi_name="";
		object spec_yushi;           //特殊玉石
		string s_log = "";
		int yushi_num = 1;
		string now = ctime(time());

		if(random(100)<85)
			spec_yushi_name = "binglanyushi";
		else 
			spec_yushi_name = "zijinyushi";
		desc += "恭喜，你获得了:\n";
		mixed err=catch{
			spec_yushi = clone(YUSHI_PATH + spec_yushi_name);
		};
		if(!err && spec_yushi){
			spec_yushi->amount = 1;
			s_log = me->query_name_cn()+"("+me->query_name()+") 打开"+box_name_cn+"时获得"+ spec_yushi->query_short()+"\n";
			Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			desc += spec_yushi->query_short()+"\n";
			spec_yushi->move_player(me->query_name());
		}
		else{
			s_log = me->query_name_cn()+"("+me->query_name()+") convert_bx_open error! 开启宝石袋时获取奖励失败\n";
			Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		}
	}
	else
		desc += "你身上没有这件物品！\n";
	desc += "[返回游戏:look]\n";
	write(desc);
	return 1;
}
