#include <command.h>
#include <gamelib/include/gamelib.h>
//��Ա�ۿ���ƷĿ¼
int main(string arg)
{
	object me = this_player();
	string item_name = "";
	string item_type = "";
	int item_cost = 0;
	sscanf(arg,"%s %s %d",item_name,item_type,item_cost);

	string s = "*** ��Ա�Ż� ***\n";
	mapping(int:int) vip_off_list = VIPD->get_vip_off_map();
	mapping(int:string) vip_list = VIPD->get_vip_name_map();
	for(int i=1;i<=sizeof(vip_off_list);i++)
	{
		s += vip_list[i]+ "("+ vip_off_list[i]+"��)\n";
	}
	int vip_level = me->query_vip_flag();
	string vip_name = vip_list[vip_level];
	item_cost = item_cost* vip_off_list[vip_level]/10;
	if(vip_level)
	{
		s += "�𾴵�"+ me->query_name_cn()+",��������"+vip_name+",��ִ�б�����ֻ�軨��"+ YUSHID->get_yushi_for_desc(item_cost)+"\n";
		s += "[ȷ��:convert_equip_confirm " + item_name+" "+item_type+" "+ item_cost+ " 2 1]\n";
		s += "[����:convert_equip_detail " + item_name +" 0]\n";	
	}
	else
	{
		s +="�㻹�������ǵĻ�Ա���Ͽ���뵽��Ա�Ĵ��ͥ�У��������Ļ�Ա��Ȩ��\n\n";                               
		s += "[�������:vip_service_app_list]\n";
		s += "[����:convert_equip_detail " + item_name +" 0]\n";
	}
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
