#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//升级换玉石推广活动页面

int main()
{
	object me = this_player();
	int level = 0;//玩家当前等级
	int yushi_num = 0;//可获得的宝石数
	int yushi_flag = 0;//领取玉石的标志位
	int yushi_level = 0;//用于判读用户能否获得玉石的标志位
	string desc="";
	level = me->query_level();
	yushi_flag = me->query_yushi_flag();
	desc += "尊敬的玩家，您当前游戏角色的等级为"+level+"级，";
	if(level >= 1){
		//desc += "已经超过了领取的上限-50级\n";
		desc += "赠送活动已经停止了，请返回。\n";
		desc += "[返回游戏:look]\n";
		write(desc);
		return 1;
	}

	int n = level/5;//判断该等级的用户可以获得多少玉石
	switch(n)
	{
		case 0:
			desc += "尚未达到领取玉石的要求，加油练级吧！\n";
			break;
		case 1:
			yushi_num = 1;
			break;
		case 2:
			yushi_num = 5;
			break;
		case 3:
			yushi_num = 10;
			break;
		case 4:
			yushi_num = 15;
			break;
		case 5..7:
			yushi_num = 20;
			break;
		case 8..10:
			yushi_num = 30;
			break;
		default:
			break;
	}

	if(0!=n)//当玩家等级不低于5级时才进行下一步操作
	{
		if(yushi_flag<5*n)
		{
			if(yushi_num<20)
				desc += "可以领取" +yushi_num+ "块碎玉。\n";
			else
				desc += "可以领取" + yushi_num/10 +"块仙缘玉\n";
			desc += "[领取玉石:tuiguang_get_yushi "+yushi_num+"]\n";
		}
		else
		{
			if(level<50)
				desc += "已领取过玉石。你尚未达到下次领取的级别，加油练级吧!\n";
			else
				desc += "已经领取过宝石。\n" ;
		}
	}
	desc += "[返回游戏:look]\n";
	write(desc);
	return 1;
}
