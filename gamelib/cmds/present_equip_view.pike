//��Ϊ�鿴���ֿɻ���Ʒ�б�
#include <command.h>
#include <gamelib/include/gamelib.h>
#define MATERIAL_PATH ROOT "/gamelib/clone/item/"
//arg = type
//   type="weapon" , "buyi"��"qingjia" or "zhongkai" "shoushi"
int main(string arg)
{
	string s = "";
	object me=this_player();
	string type = arg;
	if(type == "weapon"){
		s += "����|[����:present_equip_view buyi]|[���:present_equip_view qingjia]|[����:present_equip_view zhongkai]|[����:present_equip_view shoushi]|[����:present_equip_view other]\n";
		s += "����\n";
	}
	else if(type == "buyi"){
		s += "[����:present_equip_view weapon]|����|[���:present_equip_view qingjia]|[����:present_equip_view zhongkai]|[����:present_equip_view shoushi]|[����:present_equip_view other]\n";
		s += "����\n";
	}
	else if(type == "qingjia"){
		s += "[����:present_equip_view weapon]|[����:present_equip_view buyi]|���|[����:present_equip_view zhongkai]|[����:present_equip_view shoushi]|[����:present_equip_view other]\n";
		s += "����\n";
	}
	else if(type == "zhongkai"){
		s += "[����:present_equip_view weapon]|[����:present_equip_view buyi]|[���:present_equip_view qingjia]|����|[����:present_equip_view shoushi]|[����:present_equip_view other]\n";
		s += "����\n";
	}
	else if(type == "shoushi"){
		s += "[����:present_equip_view weapon]|[����:present_equip_view buyi]|[���:present_equip_view qingjia]|[����:present_equip_view zhongkai]|����|[����:present_equip_view other]\n";
		s += "����\n";
	}
	else if(type == "other"){
		s += "[����:present_equip_view weapon]|[����:present_equip_view buyi]|[���:present_equip_view qingjia]|[����:present_equip_view zhongkai]|[����:present_equip_view shoushi]|����\n";
		s += "[�о���x10:present_buy "+type+" liandan/xingjundan 10 0 10 0](10�����)\n";
		s += "[�Ͻ�x10:present_buy "+type+" liandan/zijindan 40 0 10 0](40�����)\n";
		s += "[����x10:present_buy "+type+" liandan/huishendan 60 0 10 0](60�����)\n";
		s += "[������x10:present_buy "+type+" liandan/yanmingdan 80 0 10 0](80�����)\n";
		s += "[�ػ굤x10:present_buy "+type+" liandan/huihundan 100 0 10 0](100�����)\n";
		s += "[��Ԫ¶x10:present_buy "+type+" liandan/fanyuanlu 10 0 10 0](10�����)\n";
		s += "[��Ԫ¶x10:present_buy "+type+" liandan/hunyuanlu 40 0 10 0](40�����)\n";
		s += "[��Ԫ¶x10:present_buy "+type+" liandan/guiyuanlu 60 0 10 0](60�����)\n";
		s += "[��ת����¶x10:present_buy "+type+" liandan/jiuzhuanxianlinglu 80 0 10 0](80�����)\n";
		s += "[�黪¶x10:present_buy "+type+" liandan/linghualu 100 0 10 0](100�����)\n";
		s += "[����ʯx1:present_buy "+type+" material/xuanhuangshi 20 0 1 0](20�����)\n";
		s += "[è��ʯx1:present_buy "+type+" material/maoyanshi 60 0 1 0](60�����)\n";
		s += "[Ѫ����x1:present_buy "+type+" material/xiehupo 100 0 1 0](100�����)\n";
		s += "[�����x1:present_buy "+type+" material/yufeicui 140 0 1 0](140�����)\n";
		s += "[�����x1:present_buy "+type+" material/jingangzuan 180 0 1 0](180�����)\n";
		s += "[��ˮ��x1:present_buy "+type+" material/zishuijing 220 0 1 0](220�����)\n";
	}
	//s += "[������Ϸ:look]\n";
	//write(s);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
