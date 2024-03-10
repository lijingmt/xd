#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEMPLATE_PATH ROOT "/gamelib/d/home/template/function/"
//实现玉石购买功能房间

int main(string arg)
{
	int yushi = 0;
	string roomName = "";
	string s = "";
	sscanf(arg,"%s %d",roomName,yushi);
	object me = this_player();
	string masterId = me->query_name();
	if(HOMED->if_have_home(masterId)){
		//判断是否有许可
		if(!HOMED->if_have_shopLicense(masterId)){
			s ="申请店铺许可，需要消耗"+YUSHID->get_yushi_for_desc(yushi)+",确认要添加吗?\n";
			s +="[确认:home_apply_shopLicense_confirm "+ roomName+" "+yushi+"]\n";
		}
		else
		{
			
			s = "你已经有了店铺许可,请不要重复申请\n";
		}
	}
	else
	{
		s = "你还没有家园，不能申请该许可。\n";
	}

	s +="[返回:look]\n";
	write(s);
	return 1;
}
