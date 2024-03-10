#include <globals.h>
#include <gamelib/include/gamelib.h>
#define TIME_UNIT 900
inherit LOW_DAEMON;
int count=0;
void create()
{
	COUNTD->read_tmp_log();
	//werror("count=%d\n",count);	
	remove_call_out(counter);
	call_out(counter,TIME_UNIT);		
}
void counter()
{
	mapping now_time = localtime(time());
	int hour = now_time["hour"];
	int minute = now_time["min"];
	count++;
	//werror("count=%d\n",count);	
	if(!(count%4)){//一小时触发事件
		COUNTD->add_online_user();//统计在线人数
		COUNTD->write_tmp_log();
	}
	if(hour==23 && (60-minute)*60<=TIME_UNIT){
		COUNTD->write_day_log();//半夜12:00左右记录到log文件
	}
	call_out(counter,TIME_UNIT);
}
