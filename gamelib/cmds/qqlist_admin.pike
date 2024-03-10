#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s,group;
	s=arg;
	//werror("qqlist_admin.pike arg="+arg+"\n");
	sscanf(arg,"%s %s",s,group);
	if(group){
		group=replace(group,(["%20":""]));
		for(int i=0;i<sizeof(group);i++){
			if(group[i]>=0&&group[i]<=127){
				if(group[i]>='a'&&group[i]<='z'||group[i]>='A'&&group[i]<='Z'||group[i]>='0'&&group[i]<='9'){
				}else{
					group=0;
					write("请使用中文、英文字母或者数字取名。\n");
					break;
				}
			}
		}
	}
	if(group==0){
		this_player()->write_view(WAP_VIEWD["/qqlist_admin_prompt"],0,0,s);
	}
	else{
		if(this_player()->qqlist_update(s,group)){
			this_player()->pop_view();
			this_player()->pop_view();
			this_player()->write_view(WAP_VIEWD["/qqlist_admin"]);
		}
		else
			this_player()->write_view(WAP_VIEWD["/qqlist_admin_prompt"],0,0,s);
	}
	return 1;
}
