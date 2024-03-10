#include <command.h>
#include <gamelib/include/gamelib.h>
//ｓｈｕｔｄｏｗｎ之前调用该指令存储帮派信息，切积极积极
int main(string arg)
{
	BANGD->save_bang(1);
	write("bangpai info is be saved ok!!\n");
	CITYD->save_city_info(1);
	write("city info is be saved ok!!\n");
	BANGZHAND->save_bangzhan_info(1); 
	write("banzhan info info is be saved ok!!\n");
	GIFTD->save_gift_info(1);
	write("gift info is be saved ok!!\n");
	HOMED->store_all_info(1);
	write("home info is be saved ok!!\n");
	AUTO_LEARND->clear_all();
	write("autoLearn info is be saved ok!!\n");
return 1;
}
