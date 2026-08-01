#include <command.h>
#include <gamelib/include/gamelib.h>

string query_potion_menu(object me)
{
	mapping(string:mapping(string:mixed)) potions =
		NEWBIED->query_catchup_exp_potions();
	array(string) order = ({"zhuiguanglu","yaoguanglu","xinghelu"});
	int level = me->query_level();
	string s = "新手追赶经验药\n\n";
	s += "药效仅作用于打怪经验，同类经验药不叠加，后服用的会覆盖原有效果。\n";
	s += "每瓶持续30分钟，70级起无法购买或服用。\n\n";
	if(level<NEWBIED->query_catchup_exp_min_buy_level()){
		s += "你当前"+level+"级，属于免费赠送阶段（1～19级）。\n";
		if(NEWBIED->query_starter_exp_potion_granted(me))
			s += "你的免费二倍追光露已经领取。\n";
		else
			s += "[免费领取二倍追光露:catchup_exp_potion claim]\n";
	}
	else if(level<=NEWBIED->query_catchup_exp_max_level()){
		s += "你当前"+level+"级，可使用玉石购买：\n";
		foreach(order,string item_name){
			mapping(string:mixed) config = potions[item_name];
			s += "["+config["name"]+":catchup_exp_potion buy "+item_name+"] ";
			s += config["price"]+"碎玉/瓶\n";
		}
		s += "\n当前玉石总价值："+YUSHID->query_all_num(me)+"碎玉；购买时会自动兑换面额。\n";
	}
	else{
		s += "你当前"+level+"级，已经超过追赶药使用阶段。\n";
		s += "70级以后不能购买或服用这三种药品。\n";
	}
	s += "\n[返回新手补给商店:newbie_shop]\n";
	s += "[普通特药商店:yushi_buy_teyao_list exp]\n";
	s += "[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	mapping(string:mapping(string:mixed)) potions =
		NEWBIED->query_catchup_exp_potions();
	string item_name = "";
	string s = "";

	if(arg=="claim"){
		mapping(string:int) result = NEWBIED->grant_starter_exp_potion(me);
		if(result["code"]==1)
			s += "领取成功：二倍追光露已放入背包，1～69级均可服用。\n";
		else if(result["code"]==2)
			s += "你的免费二倍追光露已经领取过了，每个角色只能免费领取一次。\n";
		else if(result["code"]==3)
			s += "免费赠送只面向1～19级玩家；20级后可使用玉石购买。\n";
		else
			s += "领取失败，请确认背包有空位后重试。\n";
		s += "\n[返回新手补给商店:newbie_shop]\n";
		s += "[查看追赶药:catchup_exp_potion]\n";
		s += "[返回游戏:look]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}

	if(arg && sscanf(arg,"buy %s",item_name)==1){
		mapping(string:mixed) config = potions[item_name];
		object|zero potion;
		int before;
		int after;
		int price;
		mixed err;
		mixed move_err;

		if(!config){
			s += "药品参数无效，没有发生扣款。\n";
		}
		else if(me->query_level()<NEWBIED->query_catchup_exp_min_buy_level()){
			s += "1～19级无需购买，请领取系统赠送的二倍追光露。\n";
			s += "[免费领取:catchup_exp_potion claim]\n";
		}
		else if(me->query_level()>NEWBIED->query_catchup_exp_max_level()){
			s += "70级以后不能购买或服用追赶经验药，没有发生扣款。\n";
		}
		else{
			price = (int)config["price"];
			if(YUSHID->query_all_num(me)<price){
				s += "玉石不足，需要"+price+"碎玉，当前只有"+
					YUSHID->query_all_num(me)+"碎玉。\n";
				s += "[捐赠获取仙玉:add_szx_fee]\n";
			}
			else{
				err = catch {
					potion = clone((string)config["path"]);
				};
				if(err || !potion)
					s += "药品生成失败，没有发生扣款，请稍后再试。\n";
				else if(me->if_over_load(potion)){
					s += "背包已满，无法购买；没有发生扣款。\n";
					destruct(potion);
				}
				else{
					before = NEWBIED->query_newbie_supply_amount(me,item_name);
					if(!YUSHID->pay_yushi(me,price)){
						s += "玉石扣除失败，没有获得药品，请稍后再试。\n";
						destruct(potion);
					}
					else{
						potion->amount = 1;
						move_err = catch {
							potion->move_player(me->query_name());
						};
						after = NEWBIED->query_newbie_supply_amount(me,item_name);
						if(move_err || after<=before){
							YUSHID->give_yushi(me,price);
							if(potion)
								destruct(potion);
							s += "药品放入背包失败，已退还全部玉石。\n";
						}
						else{
							s += "购买成功："+config["name"]+"，消耗"+price+"碎玉。\n";
							string log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-["+
								GAME_NAME_S+"]["+me->query_name()+"][catchup_exp_potion]["+
								item_name+"][1]["+price+"]\n";
							Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+
								"_consume_"+MUD_TIMESD->get_year_month_day()+".log",log);
						}
					}
				}
			}
		}
		s += "\n[返回新手补给商店:newbie_shop]\n";
		s += "[继续查看追赶药:catchup_exp_potion]\n";
		s += "[返回游戏:look]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}

	me->write_view(WAP_VIEWD["/emote"],0,0,query_potion_menu(me));
	return 1;
}
