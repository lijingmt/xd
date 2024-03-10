#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	int sale_id = 0;
	string gd_str = "";
	string sv_str = "";
	string s_rtn = "";
	sscanf(arg,"%d %s %s",sale_id,gd_str,sv_str);
	//sscanf(arg,"%d %s %s",sale_id,sv_str,gd_str);
	int gd_num = 0;
	int sv_num = 0;
	sscanf(gd_str,"gd=%d",gd_num);
	sscanf(sv_str,"sv=%d",sv_num);
	
	/*werror("========= [arg]="+arg +" ==========\n");
	werror("========= [gd_str]="+gd_str +" ==========\n");
	werror("========= [sv_str]="+sv_str +" ==========\n");
	werror("========= [sv_num]="+sv_num +" ==========\n");
	werror("========= [sv_num]="+sv_num +" ==========\n");
	*/
	
	if(gd_num<0 || sv_num<0){
		s_rtn +="别欺负我这样的老实人，请输入正确的竞价\n";
	}
	else if(gd_num==0 && sv_num==0){
		s_rtn +="天上可不会掉免费的烧饼~，请输入你的竞价\n";
	}
	else{
		mapping(string:mixed) sale_info = AUCTIOND->query_sale_info(sale_id);
		object ob = clone(sale_info["goods_filename"]);
		int cur_value = (int)sale_info["cur_value"];
		int end_value = (int)sale_info["end_value"];
		int now_value = gd_num*100 + sv_num;
		//11111这里需要添加玩家身上钱是否足够的判断
		if(now_value>this_player()->query_account())
			s_rtn += "你身上没有那么多钱~，请赚够钱后再来试试吧\n";
		//比较输入的竞价与当前价，低于了则提示用户
		else if(now_value<=cur_value)
			s_rtn +="你的竞价一定要高于当前价，再慷慨些吧~这东西也许就是你的了\n";
		else{
			//要是输入的竞价等于或者高于一口价，则直接胜出竞拍
			if(end_value && now_value>=end_value){
				if(!AUCTIOND->reset_sale_info(this_player(),sale_id,now_value,1))
					s_rtn += "此拍卖已经结束了\n";
				else{
					//扣除玩家竞价的费用
					this_player()->del_account(now_value);
					s_rtn +="你的竞价超过了一口价，恭喜你，你赢得了对"+ob->query_name_cn()+"的竞拍\n";
					s_rtn +="请及时领取你的物品，7天后对于这些未认领的物品我们将一律回收，以解决现在非常时期的资源紧缺问题\n";
				}
			}
			else if(this_player()->query_name()==sale_info["winner_id"])
				s_rtn +="你目前已是当前最高竞价人，别再浪费钱财，耐心等等吧\n";
			else{
				if(!AUCTIOND->reset_sale_info(this_player(),sale_id,now_value,0))
					s_rtn = "此拍卖已经结束了\n";
				else{
					//扣除玩家竞价的费用
					this_player()->del_account(now_value);
					string value_str = MUD_MONEYD->query_other_money_cn(now_value);
					s_rtn +="你当前对"+ob->query_name_cn()+"的出价为"+value_str+"\n";
				}
			}
		}
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s_rtn);
	return 1;
}




