#include <command.h>
#include <wapmud2/include/wapmud2.h>
#define ITEMSD ((object)(ROOT "/gamelib/single/daemons/itemsd.pike"))
int main(string arg)
{
	string name=arg;
	int count;
	object me = this_player();
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,me,count);
	if(ob){
		if(ob->equiped){
			me->write_view(WAP_VIEWD["/drop_equiped"],ob);
		}
		else if(ob->is("combine_item")&&ob->amount>1){
			me->write_view(WAP_VIEWD["/drop_prompt"],ob);
		}
		else if(ITEMSD->bound_item_destroyable_by_player(ob,me)){
			// 账号绑定的套装/道具没有任何转移通道；只允许本人经
			// 二次确认后销毁，否则幻境赛季背包会被永久卡满。
			string stmp = "";
			stmp += "【销毁确认】"+ob->query_name_cn()+
				"已绑定你的账号，摧毁后无法恢复！\n";
			stmp += "[是:drop_confirm "+arg+"]\n";
			stmp += "[否:inventory]\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,stmp);
			return 1;
		}
		else if(!ob->query_item_canDrop()){
			me->write_view(WAP_VIEWD["/drop_indropable"],ob);
		}
		else{
			//精致以上的物品卖或者摧毁，需要提示确定
			if(ob->query_item_rareLevel()>=3){
				string stmp = "";
				stmp += "你确定要摧毁 "+ob->query_name_cn()+"吗？\n";
				stmp += "[是:drop_confirm "+arg+"]\n";
				stmp += "[否:inventory]\n";
				me->write_view(WAP_VIEWD["/emote"],0,0,stmp);
				return 1;
			}
			string now=ctime(time());
			string s_log = me->query_name_cn()+"("+me->query_name()+")摧毁"+ob->query_name_cn()+"("+ob->query_name()+")\n";
			Stdio.append_file(ROOT+"/log/drop.log",now[0..sizeof(now)-2]+":"+s_log);
			me->pop_view();
			me->write_view(WAP_VIEWD["/drop"],ob);
			ob->remove();
		}
	}
	else{
		me->write_view(WAP_VIEWD["/drop_notfound"]);
	}
	return 1;
}
