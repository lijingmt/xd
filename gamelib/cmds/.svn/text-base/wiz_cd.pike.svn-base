/* wiz_cd.pike
 * 改变当前路径
 */
#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	//if( this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan" )
	//	return 1;
	if(!arg)
		arg="..";
	cd(arg);
	write("当前路径为： %s \n",getcwd());
	return 1;
}
