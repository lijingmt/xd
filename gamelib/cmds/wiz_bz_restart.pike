#include <command.h>
#include <gamelib/include/gamelib.h>
//ｓｈｕｔｄｏｗｎ之前调用该指令存储帮派信息，切积极积极
int main(string arg)
{
	BANGZHAND->bangzhan_restart(); 
	write("banzhan info has been reset!!\n");
	return 1;
}
