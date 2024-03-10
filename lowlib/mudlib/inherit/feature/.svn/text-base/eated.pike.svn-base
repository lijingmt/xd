
int level_limit = 1;//等级限制
mapping(string:string) race_limit=([]);//阵营限制 职业id：职业名字
mapping(string:string) profe_limit=([]);//职业限制 职业id：职业名字
int eat_flag;//吃了的标志位
//食物补充类型对应具体量值,这里预设默认值
mapping(string:int) add_supplay = ([
	"life_supply":0,
	"mofa_supply":0
]);
int is_food(){
	return 1;
}
int eat()
{
	object me = this_player();
	if(me&&me->is_character()){
		if(eat_flag){
			//1.等级检查
			if(me->query_level()<level_limit){
				return 0;//等级不够	
			}
			//2.阵营检查
			if(this_object()->race_limit[me->query_raceId()]&&sizeof(this_object()->race_limit[me->query_raceId()])){
				if(this_object()->profe_limit[me->query_profeId()]&&sizeof(this_object()->profe_limit[me->query_profeId()])){
					mapping m = this_object()->add_supplay;
					if(m&&sizeof(m)){
						foreach(indices(m),string index){
							if( (int)m[index] !=0 ){
								if(index=="life_supply"){//加血
									if(me->get_cur_life()>=me->query_life_max())
										return 11;//血够了不用重复吃药加血
									me->set_life(me->get_cur_life()+(int)m["life_supply"]);
									if(me->query_life()>me->query_life_max())
										me->set_life(me->query_life_max());
									//吃了物品，数量减一
									this_object()->amount--;
								}
								if(index=="mofa_supply"){//加蓝
									if(me->get_cur_mofa()>=me->query_mofa_max())
										return 22;//蓝够了不用重复吃药加蓝
									me->set_mofa(me->get_cur_life()+(int)m["mofa_supply"]);
									if(me->query_mofa()>me->query_mofa_max())
										me->set_mofa(me->query_mofa_max());
									this_object()->amount--;
								}
							}
						}
						//吃过了，并且吃完了，置标志位
						if(this_object()->amount<=0)
							eat_flag=0;
					}
					return 1;//成功吃药
				}
				else
					return 2;//职业不对
			}
			else
				return 3;//阵营不对
		}
		return 4;//食用已经吃过的药物,错误
	}
	return 5;//非角色执行吃药动作
}
