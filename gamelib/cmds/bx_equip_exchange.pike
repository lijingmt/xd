#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令换取帮战中可用霸王徽记换取的装备
//arg = type item_name need_xx need_money flag
//   type="weapon" ,"shipin"
//   item_name 换取的物品名
//   need_xx 需要的星星个数
//   need_money 需要的金钱数
//   flag  购买标识，1为徽记确认购买，2为G币确认购买，0为查看物品详情
private mapping(string:array(mixed)) bx_offers=([
	"weapon/29bingliedao":({"weapon",80,300000}),
	"weapon/29bingcibishou":({"weapon",60,300000}),
	"weapon/29bingyansiliezhe":({"weapon",120,300000}),
	"weapon/29lingguangzhang":({"weapon",120,300000}),
	"weapon/49xueyueshenjian":({"weapon",160,500000}),
	"weapon/49binglongzhiya":({"weapon",120,500000}),
	"weapon/49wannianhanbingfu":({"weapon",240,500000}),
	"weapon/49huanxuezhang":({"weapon",240,500000}),
	"weapon/69hanlengjian":({"weapon",240,700000}),
	"weapon/69hanbingci":({"weapon",240,700000}),
	"weapon/69hanbingshuangjian":({"weapon",480,700000}),
	"weapon/69bingyuelingzhang":({"weapon",480,700000}),
	"jewelry/29bingleixianglian":({"shipin",60,200000}),
	"jewelry/29bingrongpifeng":({"shipin",60,200000}),
	"jewelry/29binglongdiaoxiang":({"shipin",60,200000}),
	"jewelry/29bingjingzhihuan":({"shipin",60,200000}),
	"jewelry/49shuanghandiaozhui":({"shipin",120,400000}),
	"jewelry/49xuewupifeng":({"shipin",120,400000}),
	"jewelry/49bingxuenvshenxiang":({"shipin",120,400000}),
	"jewelry/49xingmangzhihuan":({"shipin",120,400000}),
	"jewelry/69hanyexianjie":({"shipin",360,600000}),
	"jewelry/69hanyepifeng":({"shipin",360,600000}),
	"jewelry/69hanfeixianglian":({"shipin",360,600000}),
	"jewelry/69hanfeishouzhuo":({"shipin",360,600000})
]);

int main(string|zero arg)
{
	string s = "这里的东西都带着冬天的气息\n";
	string s_log = ""; 
	object me=this_player();
	string type = "";
	string item_name = "";
	string mid_path = "";
	int need_xx = 0;
	int need_money = 0;
	int flag = 0;
	if(!arg || sscanf(arg,"%s %s %d %d %d",type,item_name,need_xx,
	   need_money,flag)!=5 || !bx_offers[item_name]){
		write("兑换参数无效，该物品不在圣诞兑换目录中。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	array(mixed) offer=bx_offers[item_name];
	type=(string)offer[0];
	need_xx=(int)offer[1];
	need_money=(int)offer[2];
	if(flag == 0){
		object item;
		mixed err = catch{
			item = (object)(ITEM_PATH + item_name);
		};
		if(!err && item){
			s += item->query_short()+"\n";
			s += item->query_picture_url()+"\n"+item->query_desc()+"\n";
			if(!item->is_combine_item())
				s += item->query_content()+"\n";
			string s_money = MUD_MONEYD->query_other_money_cn(need_money);
				if(need_xx > 0)
					s += "需要：【圣】圣诞星星x"+need_xx+"\n";
				if(need_money > 0)
					s += "需要："+s_money+"\n";
				s += "[换取:bx_equip_exchange "+type+" "+item_name+" "+need_xx+" "+need_money+" 1]\n";
		}
	}
	else if(flag >= 1){
		int have_xx = 0;//玩家身上拥有星星个数
		array(object) all_obj = all_inventory(me);
		foreach(all_obj,object ob){
			if(ob->is_combine_item() && ob->query_name() == "chr_xx"){
				have_xx += ob->amount;
			}
		}
		if(have_xx < need_xx){
			s += "换取失败！你身上没有足够的【圣】圣诞星星\n";
		}
		else if(me->query_account() < need_money){
			s += "换取失败！你身上没有足够的金钱\n";
		}
		else if(me->if_over_easy_load()){
			s += "换取失败！你的随身物品已满\n";
		}
		else{
			//满足换取的条件
			object item;
			mixed err = catch{
				item = clone(ITEM_PATH+mid_path+item_name);
			};
			if(!err && item){
				//删除玩家身上相应的徽记
				if(need_xx)
					me->remove_combine_item("chr_xx",need_xx);
				//删除金钱
				if(need_money)
					me->del_account(need_money);
				s += "交易成功！你获得了"+item->query_short()+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+") 花费"+need_xx+"个【圣】圣诞星星，"+need_money+"金钱，获得了"+item->query_short();
					item->move(me);
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/bx_equip_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else
				s += "交易失败！这东西似乎有点不对头\n";
		}
	}
	s += "[返回:bx_view_equiplist "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
