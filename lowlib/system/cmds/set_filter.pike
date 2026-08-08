#include <globals.h>
int main(string arg)
{
	string filter=arg;
	string param,title;
	object ob;
	mixed err;
	//[set_filter wml /xiand/main.jsp xdtest]
	if(!arg || !stringp(arg) || sizeof(arg)==0)
		return 1;
	sscanf(arg,"%s %s %s",filter,param,title);
	if(!filter || sizeof(filter)==0)
		return 1;
	// 拒绝路径穿越（_player/spliter 这种带斜杠的过滤器目前不存在，
	// 历史代码仍尝试加载。no_log + 退出，避免污染 compile_errors.log）
	if(search(filter,"/")!=-1 || search(filter,"..")!=-1)
		return 1;
	err = catch { ob=new(SROOT+"/system/filter/"+filter); };
	if(err || !ob)
		return 1;
	string s=ob->setup(param);
	if(s)
		write(s);
	set_filter(ob);
	ob->set_title(title);
	return 1;
}
