#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ����ʾ�Ƹ�������
int main(string arg)
{
	string s = "";
	object me=this_player();
	s += "�����������У�\n";
	array(mapping(string:mixed)) top_list = ({});
	if(arg=="yushi"){
		s += "��ʯ����|[��ҽ���:home_shop_sale_paihang money]\n";
		top_list = PAIHANGD->query_home_yushi_toplist();
		if(top_list && sizeof(top_list)){
			for(int i=0;i<sizeof(top_list);i++){
				string name_cn = top_list[i]["name_cn"];
				string Id = top_list[i]["id"];
				int home_yushi = (int)top_list[i]["home_yu"];
				//string account_cn = MUD_MONEYD->query_money_for_paihang(account);
				string homeId = HOMED->query_homeId_by_masterId(Id);
				//werror("-----yushi="+home_yushi+"----\n");
				if(name_cn && sizeof(name_cn)&&homeId!=""&&home_yushi){
					s += (i+1)+"��["+name_cn+"��˽��С��:home_view "+homeId+"]("+YUSHID->get_yushi_for_desc(home_yushi)+")\n";//��"+account+"��\n";
				}
			}
		}
	}
	else if(arg=="money"){
		s += "[��ʯ����:home_shop_sale_paihang yushi]|��ҽ���\n";
		top_list = PAIHANGD->query_home_money_toplist();
		if(top_list && sizeof(top_list)){
			for(int i=0;i<sizeof(top_list);i++){
				string name_cn = top_list[i]["name_cn"];
				string Id = top_list[i]["id"];
				int home_money = (int)top_list[i]["home_bi"];
				//string account_cn = MUD_MONEYD->query_money_for_paihang(account);
				string homeId = HOMED->query_homeId_by_masterId(Id);
				if(name_cn && sizeof(name_cn)&&homeId!=""&&home_money){
					s += (i+1)+"��["+name_cn+"��˽��С��:home_view "+homeId+"]("+MUD_MONEYD->query_store_money_cn(home_money)+")\n";//��"+account+"��\n";
				}
			}
		}
	}
	else
		s += "��δ����\n";
	//s += "[ˢ�����а�:paihang_update_account_toplist]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[������Ϸ:look]\n";
	//write(s);
	return 1;
}
