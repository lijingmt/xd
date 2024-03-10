//收费道具玉石的功能模块，提供玉石兑换，消费，整理的接口
//
//由liaocheng于07/11/07开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>

private mapping(int:int) rarelevel_value = ([1:1,2:10,3:100,4:1000,5:10000]); //玉石稀有度与等量价值的对照表
private mapping(int:string) rarelevel_namecn = ([1:"【玉】碎玉",2:"【玉】仙缘玉",3:"【玉】玲珑玉",4:"【玉】碧銮玉",5:"【玉】玄天宝玉"]);//玉石稀有度与玉石名字的对应表
private mapping(int:string) rarelevel_namecn_clear = ([1:"碎玉",2:"仙缘玉",3:"玲珑玉",4:"碧銮玉",5:"玄天宝玉"]);//玉石稀有度与玉石名字的对应表,去掉前缀
private mapping(int:string) rarelevel_name = ([1:"suiyu",2:"xianyuanyu",3:"linglongyu",4:"biluanyu",5:"xuantianbaoyu"]);//玉石稀有度与玉石的对应表

void create()
{

}


string query_can_update(object player)
{
	string s_rtn = "";
	mapping(int:int) tmp_m=([]);//记录玩家现在身上各种稀有度玉石的个数
	//首先获得玩家玉石的个数信息
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			int rare = ob->query_yushi_rarelevel();
			//只有合成二级以上的玉石，也就是说只有一级到四级的才能作为合成材料
			if(rare>0 && rare<5){
				if(!tmp_m[rare])
					tmp_m[rare] = ob->amount;
				else
					tmp_m[rare] += ob->amount;
			}
		}
	}
	//然后分别列出可以合成的玉石列表
	if(sizeof(tmp_m)){
		foreach(sort(indices(tmp_m)),int rarelevel){
			if(rarelevel>0 && rarelevel<5){
				int num = tmp_m[rarelevel]/10;
				if(num > 0){
					s_rtn += "[合成"+rarelevel_namecn[rarelevel+1]+":yushi_update_detail "+rarelevel_name[rarelevel+1]+" "+(rarelevel+1)+"](x"+num+")\n";
				}
			}
		}
	}
	return s_rtn;
}

//根据稀有度获得玉石的名字
string get_yushi_namecn(int rarelevel)
{
	return rarelevel_namecn[rarelevel];
}
//根据稀有度获得玉石的文件名
string get_yushi_name(int rarelevel)
{
	return rarelevel_name[rarelevel];
}

//查询能够合成的某稀有度玉石的个数
//这个也用于判断是否可以合成，防止玩家非法刷
int query_update_num(object player,int rarelevel)
{
	int num_rtn = 0;
	array(object) all_obj = all_inventory(player);
	rarelevel--;
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			if(ob->query_yushi_rarelevel()==rarelevel)
				num_rtn += ob->amount;
		}
	}
	num_rtn = num_rtn/10;
	return num_rtn;
}


//查询玩家能够打碎的玉石列表
string query_can_degrade(object player)
{
	string s_rtn = "";
	mapping(int:int) tmp_m=([]);//记录玩家现在身上各种稀有度玉石的个数
	//首先获得玩家玉石的个数信息
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			int rare = ob->query_yushi_rarelevel();
			//只有合成二级以上的玉石，也就是说只有一级到四级的才能作为合成材料
			if(rare>1 && rare<=5){
				if(!tmp_m[rare])
					tmp_m[rare] = ob->amount;
				else
					tmp_m[rare] += ob->amount;
			}
		}
	}
	//然后分别列出可以合成的玉石列表
	if(sizeof(tmp_m)){
		foreach(sort(indices(tmp_m)),int rarelevel){
			if(rarelevel>1 && rarelevel<=5){
				int num = tmp_m[rarelevel];
				if(num > 0){
					s_rtn += "[打碎"+rarelevel_namecn[rarelevel]+":yushi_degrade_detail "+rarelevel_name[rarelevel-1]+" "+(rarelevel-1)+"](x"+num+")\n";
				}
			}
		}
	}
	return s_rtn;
}


//判断玩家能否打碎某稀有度玉石，防止玩家刷
//玩家player有多少个材料可以打碎为rarelevel等级的玉石
int query_degrade_num(object player,int rarelevel)
{
	int num_rtn = 0;
	array(object) all_obj = all_inventory(player);
	rarelevel++;
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			if(ob->query_yushi_rarelevel()==rarelevel)
				num_rtn += ob->amount;
		}
	}
	return num_rtn;
}

//得到玩家所有的玉石(换算成碎玉)之后的数目
int query_all_num(object player)
{
	int re = 0;
	int tmp = 0;//每种玉的个数；
	int tmp_num = 1;//每种玉与碎玉的比率
	for(int i=1;i<6;i++)
	{
		tmp = query_yushi_num(player,i);
		if (tmp)
		{
			for(int m=0;m<i-1;m++)
			{
				tmp_num = tmp_num *10;	
			}
			re += tmp * tmp_num;
			tmp_num = 1;//将比率重置为1
		}
	}
	return re;
}
/* 【方法描述】 判断玩家身上的玉石是否够支付
       【变量】 player    玩家
                num       需要支付的玉石数量(以碎玉为单位)
     【返回值】 0: 玉石不够
                1：足够支付
      【说明】  这个方法是实现主要利用了"取整"、"取余"这两个操作。实现逻辑为：
                 (1) 得到玩家身上各种玉石的数目；
	         (2) 判断玩家是否有足够多的"碎玉" (num对10取余就能得到需要支付的碎玉数)
	         (3) 如果碎玉的数量足够，则用 num对10"取整"，从而得到需要的"仙缘玉"数目；
	         (4) 重复(2)(3)步操作，直到判断完最高级的玉石"玄天宝玉"；
	         (5) (2)(3)(4)中，只要有任何一种玉石的数目不足，则直接返回"0"
	    例如：某人身上的玉石数目是 2块玄天宝玉   3块碧銮玉   5块玲珑玉 4块仙缘玉 5块碎玉
	          而需要支付的数目是  345 碎玉
                  当方法运行时：(1) num = 345，对10取余，得到 5 ，而此人正好有5块碎玉，则满足条件，进入下一步；
                                (2) num对10取整，得到新的 num=34；
				(3) 此时，num=34 对10取余，得到 4 ，这就是需支付的仙缘玉个数，依次循环，最终实现判断功能
    【author】Evan 2008.07.25 
   */
int have_enough_yushi(object player,int num)
{
	mapping(int:int) my_num =([]);//玩家各种玉石的数目列表
	int tmp = 0;//每种玉的个数；
	for(int i=1;i<6;i++)//得到玩家身上各种玉石的数目
	{
		tmp = query_yushi_num(player,i);
		my_num[i]=tmp;
	}
	for(int m=1;m<6;m++)
	{
		if(my_num[m]<(num%10))//如果有一类玉石的数目不够，则直接返回 0 ;
		{
			return 0;
		}
		num = num/10;
		if(!num)
		break;
	}
	return 1;
}
/*
   方法描述：扣出玩家身上的玉石
       变量：player    玩家
             num       需要扣除的玉石数量(以碎玉为单位)
     返回值：0: 扣除失败
             1：扣除成功
    author: Evan 2008.07.25 
 */
int pay_yushi(object player,int num)
{
	if(!have_enough_yushi(player,num))//如果玉石不够支付，直接返回失败
	{
		return 0;
	}
	else
	{
		mapping(int:int) all_yushi = ([]);//需要扣除的玉石列表
		string yushi = "";//需要扣除的玉石名
		int re_num = 0;//扣除操作的返回值
		for(int i=1;i<6;i++)
		{
			all_yushi[i] = num%10;
			num = num/10;
			if(!num) break;
		}
		for(int m=1;m<6;m++)//按列表扣除石头
		{
			if(all_yushi[m])//如果该类玉石的扣除数不为0
			{
				yushi = get_yushi_name(m);//得到此类玉石的文件名
				re_num = player->remove_combine_item(yushi,all_yushi[m]);//扣除玉石
			}
			if(re_num != all_yushi[m])//扣除时出错
			return 0;
			re_num = 0;//标志位归零
		}
	}
	return 1;
}

/*
   方法描述：给玩家添加玉石
       变量：player    玩家
             num       需要添加的玉石数量(以碎玉为单位)
     返回值：0: 添加失败
             1：添加成功
    author: Evan 2008.09.19 
 */
int give_yushi(object player,int num)
{
	//werror("==== num = "+num+"======\n");
	mapping(int:int) all_yushi = ([]);//需要添加的玉石列表
	string yushi = "";//需要添加的玉石名
	string yushiPath = "";//玉石的路径
	for(int i=1;i<6;i++)
	{
		all_yushi[i] = num%10;
		num = num/10;
		if(!num) break;
	}
	for(int m=1;m<6;m++)//按列表添加石头
	{
		//werror("==== m = "+m+"======\n");
		if(all_yushi[m])//如果该类玉石数目不为0
		{
			yushi = get_yushi_name(m);//得到此类玉石的文件名
			yushiPath = ITEM_PATH +"yushi/" + yushi;
			object yushiNew = clone(yushiPath);
			yushiNew->amount=all_yushi[m];
			yushiNew->move_player(player->query_name());
		}
	}
	return 1;
}
//获得玩家拥有某种玉石的个数，购买物品时调用
int query_yushi_num(object player,int rarelevel)
{
	int num_rtn = 0;
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			if(ob->query_yushi_rarelevel()==rarelevel)
				num_rtn += ob->amount;
		}
	}
	return num_rtn;
}
//返回玩家身上所有玉石的中文描述
string query_yushi_cn(object player)
{
	string s_rtn = "";
	mapping(int:int) tmp_m=([]);//记录玩家现在身上各种稀有度玉石的个数
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			int rare = ob->query_yushi_rarelevel();
			if(rare>0 && rare<=5){
				if(!tmp_m[rare])
					tmp_m[rare] = ob->amount;
				else
					tmp_m[rare] += ob->amount;
			}
		}
	}
	if(sizeof(tmp_m)){
		array artmp = sort(indices(tmp_m));
		for(int i=sizeof(artmp);i>0;i--)
		{
			int rarelevel = artmp[i-1];
			if(rarelevel>0 && rarelevel<6){
				int num = tmp_m[rarelevel];
				if(num > 0){
					s_rtn += rarelevel_namecn_clear[rarelevel]+"："+num+"\n";
				}
			}
		}
	}
return s_rtn;
}
//获得一定数量玉石的描述性语言
//参数是以碎玉为单位的价值
//如value =11 则此接口返回1【玉】仙缘玉1【玉】碎玉
string get_yushi_for_desc(int value)
{
	string s_rtn = "";
	if(value){
		int biluanyu = 0;
		int linglongyu = 0;
		int xianyuanyu = 0;
		int suiyu = 0;
		int xuantianbaoyu = value/10000;
		if(xuantianbaoyu){
			s_rtn += xuantianbaoyu+"【玉】玄天宝玉";
			value = value%10000;
		}
		biluanyu = value/1000;
		if(biluanyu){
			s_rtn += biluanyu+"【玉】碧銮玉";
			value = value%1000;
		}
		linglongyu = value/100;
		if(linglongyu){
			s_rtn += linglongyu+"【玉】玲珑玉";
			value = value%100;
		}
		xianyuanyu = value/10;
		if(xianyuanyu){
			s_rtn += xianyuanyu+"【玉】仙缘玉";
			value = value%10;
		}
		suiyu = value;                                                                                    
		if(suiyu)
			s_rtn += suiyu+"【玉】碎玉";
	}
	return s_rtn;
}

//与yushi_add_fee.pike相对应的玉石的描述,与它联合使用来告诉玩家获得玉的情况
//arg = fee yushi_level
string query_yushi_add_fee_desc(int fee,int yushi_level)
{
	string s_rtn = "";
	if(fee > 20 && yushi_level < 5){
		int up_fee = fee/10;
		fee = fee%10;
		int up_yushi_level = yushi_level+1;
		s_rtn += query_yushi_add_fee_desc(up_fee,up_yushi_level);
		if(fee > 0)
			s_rtn += query_yushi_add_fee_desc(fee,yushi_level);
	}
	else{
		string yushi_name_cn = get_yushi_namecn(yushi_level);
		s_rtn += fee+yushi_name_cn;
	}
	return s_rtn;
}
