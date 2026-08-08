#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	object view;
	// 登录阶段的 LOW_USER 也能看到 gamelib 命令目录，但它尚未继承
	// WAP 视图栈。旧网页探测请求会因此把 look 发给半初始化对象。
	if(!me || !functionp(me->reset_view) || !functionp(me->write_view))
		return 0;
	if(me->sid=="5dwap"){
		int tmp = time() - (int)me["/push/push_time"];
		if(tmp>=300){
			//tell_object(this_player(),"欢迎尝试仙道，您现在是游客身份，你的档案将不会被保存，欢迎点击注册一个正式帐号来体验仙道的乐趣。\n[免费注册:reg_account]\n");
			//return 1;
		}
	}
	if(me->in_combat){
		view = WAP_VIEWD["/fight"];
	}
	else
		view = WAP_VIEWD["/look"];
	if(!view)
		return 0;
	me->reset_view(view);
	me->write_view();
	return 1;
}
