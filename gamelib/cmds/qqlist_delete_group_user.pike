#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string groupId = "";
	string is_sure = "";
	int n = sscanf(arg,"%d %s",groupId,is_sure);
	//werror("----------n="+n+"---\n");
	if(n==1){
		groupId = arg;
		//werror("------------groupId="+groupId+"--\n");
		if(me->groupList[groupId] && sizeof(me->groupList[groupId])){
		//werror("------------groupId="+groupId+"-groupName ="+me->groupList[groupId]+"-\n");
			s += "您确定要删除"+me->groupList[groupId]+"组的所有好友吗?\n\n";
			s += "[确定删除:qqlist_delete_group_user "+groupId+" yes]\n";
		}
		else{
			s += "该组不存在\n";
		}
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(n==2){
		groupId = (string)groupId;//由于qqlist_delete_group_user方法中需要的参数为string型，所以需要转化一下
		if(is_sure == "yes"){
			int t = me->qqlist_delete_group_user(groupId);
			if(t)
				s += "操作已成功，请返回。\n";
			else
				s += "操作失败，请返回重试。\n";
		}
	}
	s += "[返回:my_qqlist]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
