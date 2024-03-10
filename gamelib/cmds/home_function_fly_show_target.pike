#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "\n\n";
	if(HOMED->if_have_home(me->query_name()))
	{
		string targetPath = room->flyTarget;
		if(targetPath)
		{
			object targetRoom = 0;
			mixed err = catch{
				targetRoom = clone(targetPath);
			};
			if(!err && targetRoom){
				s += "你目前关联的房间是："+ targetRoom->query_name_cn()+"\n";
				s += "如果需要改变关联房间，可以在杂货商人处购买新的传送神符。\n";
				array(string) tmp = targetPath/("gamelib/d/");
				string roomPath = tmp[1];
				s += "[确认传送:qge74hye "+ roomPath +"]\n";
			}
			else
			{
				s +=  "由于传送阵不太稳定，暂时未能发现你的传送目的地，如有疑问，请与客服联系。\n";
			}
		}
		else
		{
			s += "你尚未指定相关联的房间。\n";
			s += "请先进入需要传送的房间，然后使用 '传送神符'实现关联，关联后可反复传送。\n";
			s += "在添加房间时，你已免费获得一张传送神符。如果需要改变关联房间，可以在杂货商人处购买新的传送神符。\n";
		}
	}
	else
	{
		s += "你现在还没有家园，不能完成该操作\n";

	}
	s += "\n[返回:look]\n";
	write(s);
	return 1;
}
