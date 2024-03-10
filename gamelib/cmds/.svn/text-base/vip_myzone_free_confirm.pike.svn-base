#include <command.h>
#include <gamelib/include/gamelib.h>
//确认领取某种宝石

int main(string arg)
{
	object me = this_player();
	string goods_path= "";
	int lv = 0;
	string re = "";
	string s_log = "";
	sscanf(arg,"%s %d",goods_path,lv);
	array(string) tmp = ({});
	string type = "baoshi";                        //默认的物品类型
	tmp = goods_path/"/";                          //得到文件所在目录，也就是物品的分类
	if(tmp)                                  
	{
		type=tmp[0];
	}
	object goods = clone(ITEM_PATH+goods_path);
	string goods_name = goods->query_name();
	goods->set_toVip(1);	
	string goods_namecn = goods->query_name_cn();
	int result = VIPD->if_can_get_freely(me,goods,lv);//判断该玩家是否能获得该物品
	if(result ==4)//可以获得物品
	{
		goods->move_player(me->query_name());
		string s_log = me->query_name_cn()+"("+me->query_name()+")获得免费物品"+goods_namecn+"("+goods_name+")\n";
		Stdio.append_file(ROOT+"/log/get_vip_free_item.log",MUD_TIMESD->get_mysql_timedesc()+":"+s_log);
	}
	re += VIPD->if_can_get_freely_desc(result,lv,goods_namecn);

	re += "[继续领取:vip_myzone_free_list "+ type +" "+ lv +"]\n";
	re += "[返回游戏:look]\n";
	write(re);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
