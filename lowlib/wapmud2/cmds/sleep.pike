#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	object env=environment(this_player());
	if(env&&env->is("bedroom")){
		this_player()->sleep();

		//由liaocheng于07/1/9添加文档注释
		//其实这里并不会真正执行write_view（）方法，
		//因为在this_player()->sleep()(mudlib/inherit/feature/char.pike中实现的)中已经通过调用
		//  efuns->disable_command()屏蔽了所有指令.
		//这条指令的唯一用处就是触发efuns->command()里关于if(!living(this)){..} 中代码的执行，
		//  从而调用wapmud2/inherit/user.pike->query_UNCONSCIOUS(),得到真正的输出信息;
		//从这里看出了efuns->command()里关于屏蔽指令的巧妙之处,汗~~~
		this_player()->write_view(WAP_VIEWD["/look"]);
	}
	else{
		this_player()->write_view(WAP_VIEWD["/sleep_nobedroom"]);
	}
	return 1;
}
