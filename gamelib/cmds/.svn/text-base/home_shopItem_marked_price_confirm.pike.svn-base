#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string name ="";
	int count = 0;//出售数量
	int fg = 0;//价格标志，0为金钱，1为玉石
	int delay = 0;//出售期限
	int ind = 0; //摆摊位置
	int price =0 ;
	int amount = 1;
	object ob;
	object env=environment(me);
	string s = "";
	sscanf(arg,"%d %s %d %d %d %d",fg,name,count,delay,price,ind);
	array(object) all_ob = all_inventory(me);
	foreach(all_ob,object each_ob){
		if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
			ob = each_ob;
			break;
		}
	}
	if(env && ob){
		string filePath = file_name(ob);
		filePath = (filePath/"#")[0];
		//werror("-----"+ITEM_PATH+"---\n");
		filePath = filePath - ITEM_PATH;
		string s_log = me->query_name_cn()+"("+me->query_name()+")在私家小店出售"+ob->query_name_cn()+",数量为"+count+".\n";
		string now = ctime(time());
		Stdio.append_file(ROOT+"/log/home/baitan.log",now[0..sizeof(now)-2]+":"+s_log);
		if(ob->is("combine_item")){
			amount = count;
			me->remove_combine_item(name,count);
		}
		else
			ob->remove();
		string shopInfo = filePath+"#"+time()+"#"+delay+"#"+price+":"+fg+"#0#"+amount+"#";
		//werror("----shopInfo="+shopInfo+"---\n");
		HOMED->save_shopItem(me->query_name(),shopInfo,ind);
		//me->command("/home_move sijiaxiaodian");
		s += "摆摊成功\n";
	}
	else{
		s += "您身上已经没有这件物品\n";
	}
	s += "[返回:home_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
