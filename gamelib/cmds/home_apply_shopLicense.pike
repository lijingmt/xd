#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEMPLATE_PATH ROOT "/gamelib/d/home/template/function/"
//ʵ����ʯ�����ܷ���

int main(string arg)
{
	int yushi = 0;
	string roomName = "";
	string s = "";
	sscanf(arg,"%s %d",roomName,yushi);
	object me = this_player();
	string masterId = me->query_name();
	if(HOMED->if_have_home(masterId)){
		//�ж��Ƿ������
		if(!HOMED->if_have_shopLicense(masterId)){
			s ="���������ɣ���Ҫ����"+YUSHID->get_yushi_for_desc(yushi)+",ȷ��Ҫ�����?\n";
			s +="[ȷ��:home_apply_shopLicense_confirm "+ roomName+" "+yushi+"]\n";
		}
		else
		{
			
			s = "���Ѿ����˵������,�벻Ҫ�ظ�����\n";
		}
	}
	else
	{
		s = "�㻹û�м�԰�������������ɡ�\n";
	}

	s +="[����:look]\n";
	write(s);
	return 1;
}
