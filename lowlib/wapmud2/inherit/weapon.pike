#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_WEAPON;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
//����������Ʒ�������ش˷�������Ϊ����װ��״̬
string query_inventory_links(void|int count)
{
	if(!equiped){
		return ::query_inventory_links(count)+"[װ��:wield "+name+" "+count+"]";
	}
	else{
		return ::query_inventory_links(count)+"[����:unwield "+name+" "+count+"]";
	}
}
string query_extra_links(void|int count)
{
	return "";
}
