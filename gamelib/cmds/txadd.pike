/**                                                                                                                          
 * 提供修改通宝的功能
 * @author jess
 * @date 19/04/2007
 */

#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s="";
	string name = arg;
	int fe = 1;
	int remove_flag=0;

	if(sscanf(arg,"%s %d",name,fe)!=2){
		//s+="请输入充值的通宝数[string:txadd "+name+" ...]\n";
		s+="[充值50元:txadd "+name+" 50]\n";
		s+="[充值100元:txadd "+name+" 100]\n";
		s+="[充值200元:txadd "+name+" 200]\n";
		s+="[充值300元:txadd "+name+" 300]\n";
		s+="[充值400元:txadd "+name+" 400]\n";
		s+="[充值500元:txadd "+name+" 500]\n";
		s += "[返回上级:mgr_usr_data "+name+"]\n";
		s += "[返回管理主界面:game_deal]\n";
		s+="[返回游戏:look]\n";
		write("%s",s);
		return 1;
	}
	else{
		object player = find_player(name);
		if(!player)
		{
			player=this_player()->load_player(name);
			remove_flag=1;                                                                                      
		}
		if(!player && (remove_flag==1)){
			s += "没有这个游戏id，请核对后再查。\n";
			s += "[返回上级:mgr_usr_data "+name+"]\n";
			s += "[返回管理主界面:game_deal]\n";
			s+="[返回游戏:look]\n";
			write("%s",s);
			return 1;
		}
		if(player){
			string lgs = "操作人："+this_player()->name+"|"+this_player()->name_cn+"||||"+name+"|"+player->name_cn;//+"|当前通宝："+player->query_tongbao()+"|";
			lgs += "|充值："+(fe)+"|\n";
			s = "用户名："+name+"|充值："+fe;//+"|该用户当前通宝为："+player->query_tongbao()+"\n";
			//player->command("wiz_add_fee "+name+" "+fe);
			
			////////////////////////////////////////////////////////////////////////
			player->command("yushi_add_fee "+fe+" 2 szx");	
			////////////////////////////////////////////////////////////////////////
			
			//lgs += "|最后通宝："+player->query_tongbao()+"\n";
			s += "用户名："+name+"|充值："+fe;//+"|该用户充值后通宝为："+player->query_tongbao()+"\n";
			mapping now_time = localtime(time());
			string now = ctime(time());
			int year = now_time["year"] + 1900;
			int mon = now_time["mon"]+1;                                               
			Stdio.append_file(ROOT+"/log/manage_addfee.log",now[0..sizeof(now)-2]+"|"+lgs);
			//s += "通宝数 "+(fe*10)+" 充值成功，请返回。\n";
			s += "充值成功，请返回。\n";
			player->command("save");
		}
		if(remove_flag){
			//player->remove();	
			//删除是肯定的，但不要使用remove，否则直接删除对象
			player->net_dead();
		}
	}
	s += "[返回:mgr_usr_data "+name+"]\n";
	s += "[返回管理主界面:game_deal]\n";
	s += "[返回游戏:look]\n";
	write("%s",s);
	return 1;
}
