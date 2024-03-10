#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string desc="";
	if(!arg){
		desc += "请输入要创建的新组的名字：\n";	
		desc+="[qqlist_group_create ...]\n";
		desc+="[返回:qqlist_admin_groups]\n";
		write(desc);
		return 1;
	}
	else{
		arg=replace(arg,"|","：");
   		arg=replace(arg,",","，");
		arg=replace(arg,".","。");
		arg=replace(arg,"->","－>");
		arg=replace(arg,"\"","“");
		arg=replace(arg,"\r\n","");
		arg=replace(arg,":","：");
		arg=replace(arg,"[","「");
		arg=replace(arg,"]","」");
		arg=replace(arg,"%20"," ");	
		for(int i=0;i<sizeof(arg);i++){
			if(arg[i]>=0&&arg[i]<=127){
				if(arg[i]>='a'&&arg[i]<='z'||arg[i]>='A'&&arg[i]<='Z'||arg[i]>='0'&&arg[i]<='9'){
				}else{
					arg=0;
					break;
				}
			}
		}
 		if(!arg)
		{
      		desc+="输入错误，请输入中文，英文字母或者数字。\n";
			desc+="请输入要创建的新组的名字：\n";	
			desc+="[qqlist_group_create ...]\n";
		}
		else if(sizeof(arg)>=20||sizeof(arg)<=1)
		{
   			desc+= "名字长度不能小于1个字符或者超过20个字符。\n";
			desc+="请输入要创建的新组的名字：\n";	
			desc+="[qqlist_group_create ...]\n";
		}
		else
		{
			int t = this_player()->qqlist_group_create(arg);
			if(t==1)
				desc += "创建成功，请返回。\n";
			else if(t==2)
				desc += "该组已经存在，请返回重新输入组名。\n";
			else
				desc+="创建新组失败，请返回重试。\n";	
		}
	}
	desc+="[返回:qqlist_admin_groups]\n";
	write(desc);
	return 1;
}
