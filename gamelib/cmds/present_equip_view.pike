//此为查看积分可换物品列表
#include <command.h>
#include <gamelib/include/gamelib.h>
#define MATERIAL_PATH ROOT "/gamelib/clone/item/"
//arg = type
//   type="weapon" , "buyi"，"qingjia" or "zhongkai" "shoushi"
int main(string arg)
{
	string s = "";
	object me=this_player();
	string type = arg;
	if(type == "weapon"){
		s += "武器|[布衣:present_equip_view buyi]|[轻甲:present_equip_view qingjia]|[重铠:present_equip_view zhongkai]|[首饰:present_equip_view shoushi]|[其他:present_equip_view other]\n";
		s += "暂无\n";
	}
	else if(type == "buyi"){
		s += "[武器:present_equip_view weapon]|布衣|[轻甲:present_equip_view qingjia]|[重铠:present_equip_view zhongkai]|[首饰:present_equip_view shoushi]|[其他:present_equip_view other]\n";
		s += "暂无\n";
	}
	else if(type == "qingjia"){
		s += "[武器:present_equip_view weapon]|[布衣:present_equip_view buyi]|轻甲|[重铠:present_equip_view zhongkai]|[首饰:present_equip_view shoushi]|[其他:present_equip_view other]\n";
		s += "暂无\n";
	}
	else if(type == "zhongkai"){
		s += "[武器:present_equip_view weapon]|[布衣:present_equip_view buyi]|[轻甲:present_equip_view qingjia]|重铠|[首饰:present_equip_view shoushi]|[其他:present_equip_view other]\n";
		s += "暂无\n";
	}
	else if(type == "shoushi"){
		s += "[武器:present_equip_view weapon]|[布衣:present_equip_view buyi]|[轻甲:present_equip_view qingjia]|[重铠:present_equip_view zhongkai]|首饰|[其他:present_equip_view other]\n";
		s += "暂无\n";
	}
	else if(type == "other"){
		s += "[武器:present_equip_view weapon]|[布衣:present_equip_view buyi]|[轻甲:present_equip_view qingjia]|[重铠:present_equip_view zhongkai]|[首饰:present_equip_view shoushi]|其他\n";
		s += "[行军丹x10:present_buy "+type+" liandan/xingjundan 10 0 10 0](10点积分)\n";
		s += "[紫金丹x10:present_buy "+type+" liandan/zijindan 40 0 10 0](40点积分)\n";
		s += "[回神丹x10:present_buy "+type+" liandan/huishendan 60 0 10 0](60点积分)\n";
		s += "[延命丹x10:present_buy "+type+" liandan/yanmingdan 80 0 10 0](80点积分)\n";
		s += "[回魂丹x10:present_buy "+type+" liandan/huihundan 100 0 10 0](100点积分)\n";
		s += "[返元露x10:present_buy "+type+" liandan/fanyuanlu 10 0 10 0](10点积分)\n";
		s += "[混元露x10:present_buy "+type+" liandan/hunyuanlu 40 0 10 0](40点积分)\n";
		s += "[归元露x10:present_buy "+type+" liandan/guiyuanlu 60 0 10 0](60点积分)\n";
		s += "[九转仙灵露x10:present_buy "+type+" liandan/jiuzhuanxianlinglu 80 0 10 0](80点积分)\n";
		s += "[灵华露x10:present_buy "+type+" liandan/linghualu 100 0 10 0](100点积分)\n";
		s += "[玄黄石x1:present_buy "+type+" material/xuanhuangshi 20 0 1 0](20点积分)\n";
		s += "[猫眼石x1:present_buy "+type+" material/maoyanshi 60 0 1 0](60点积分)\n";
		s += "[血琥珀x1:present_buy "+type+" material/xiehupo 100 0 1 0](100点积分)\n";
		s += "[玉翡翠x1:present_buy "+type+" material/yufeicui 140 0 1 0](140点积分)\n";
		s += "[金刚钻x1:present_buy "+type+" material/jingangzuan 180 0 1 0](180点积分)\n";
		s += "[紫水晶x1:present_buy "+type+" material/zishuijing 220 0 1 0](220点积分)\n";
	}
	//s += "[返回游戏:look]\n";
	//write(s);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
